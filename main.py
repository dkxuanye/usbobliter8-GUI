#!/usr/bin/env python3

import sys
import threading
import time
from pathlib import Path

import usb
import usb.util
from PyQt5.QtCore import QObject, Qt, QTimer, pyqtSignal
from PyQt5.QtWidgets import (
    QApplication, QLabel, QMainWindow, QMessageBox, QPushButton, QVBoxLayout,
    QWidget,
)
from pymobiledevice3.irecv import IRecv

APPLE_VENDOR_ID = 0x05AC
DFU_PRODUCT_ID = 0x1227
DFU_DNLOAD = 1
DFU_ABORT = 4
CUSTOM_BOOT = 8
DFU_REQUEST_TYPE = 0x21
DFU_TRANSFER_SIZE = 0x800

SUPPORTED_CPIDS = {"0x8020", "0x8030"}

# (cpid, bdid) -> (name, iBoot codename)
DEVICES = {
    # A12 (0x8020)
    ("0x8020", 0x0A): ("iPhone XS Max", "d331"),
    ("0x8020", 0x0C): ("iPhone XR", "n841"),
    ("0x8020", 0x0E): ("iPhone XS", "d321"),
    ("0x8020", 0x1A): ("iPhone XS Max", "d331p"),
    ("0x8020", 0x14): ("iPad mini 5", "j210"),
    ("0x8020", 0x16): ("iPad mini 5", "j210"),
    ("0x8020", 0x1C): ("iPad Air 3", "j217"),
    ("0x8020", 0x1E): ("iPad Air 3", "j217"),
    ("0x8020", 0x24): ("iPad (8th gen)", "ipad11b"),
    ("0x8020", 0x26): ("iPad (8th gen)", "ipad11b"),
    
    # A13 (0x8030)
    ("0x8030", 0x02): ("iPhone 11 Pro Max", "d431"),
    ("0x8030", 0x04): ("iPhone 11", "n104"),
    ("0x8030", 0x06): ("iPhone 11 Pro", "d421"),
    ("0x8030", 0x10): ("iPhone SE (2nd gen)", "d79")
}

IBEC_DIR = Path(getattr(sys, "_MEIPASS", Path(__file__).resolve().parent)) / "boot"

GREEN, RED, MUTED = "#1a7f37", "#cf222e", "#adb6c1"


def _serial_field(serial, key):
    for part in (serial or "").split():
        if part.startswith(f"{key}:"):
            return part.split(":", 1)[1]
    return None


def identify(cpid_key, bdid_raw):
    try:
        return DEVICES.get((cpid_key, int(bdid_raw, 16)))
    except (ValueError, TypeError):
        return None


def ibec_path_for(codename):
    return IBEC_DIR / f"iBEC.{codename}.RELEASE.patched"


def dfu_upload(dev, buf):
    for off in range(0, len(buf), DFU_TRANSFER_SIZE):
        dev.ctrl_transfer(DFU_REQUEST_TYPE, DFU_DNLOAD, 0, 0,
                          buf[off:off + DFU_TRANSFER_SIZE], 2000)
    dev.ctrl_transfer(DFU_REQUEST_TYPE, DFU_DNLOAD, 0, 0, None, 100)


def dfu_boot(dev):
    dev.ctrl_transfer(DFU_REQUEST_TYPE, CUSTOM_BOOT, 0, 0, None, 100)
    try:
        dev.ctrl_transfer(DFU_REQUEST_TYPE, DFU_ABORT, 0, 0, None, 100)
    except usb.core.USBError:
        pass
    usb.util.dispose_resources(dev)


def _dfu_serial(dispose=False):
    dev = usb.core.find(idVendor=APPLE_VENDOR_ID, idProduct=DFU_PRODUCT_ID)
    if dev is None:
        return None, None
    try:
        serial = dev.serial_number or ""
    except Exception:
        serial = ""
    if dispose:
        usb.util.dispose_resources(dev)
    return dev, serial


class Detector(QObject):
    detected = pyqtSignal(object)

    def __init__(self):
        super().__init__()
        self._stop = False
        self._paused = False
        threading.Thread(target=self._loop, daemon=True).start()

    def _loop(self):
        while not self._stop:
            if not self._paused:
                try:
                    dev, serial = _dfu_serial(dispose=True)
                    info = None if dev is None else (
                        _serial_field(serial, "CPID"),
                        _serial_field(serial, "BDID"),
                        "PWND:[" in serial)
                except Exception:
                    info = None
                try:
                    self.detected.emit(info)
                except RuntimeError:
                    return
            end = time.time() + 1.2
            while not self._stop and time.time() < end:
                time.sleep(0.1)


class Obliter8Worker(QObject):
    step = pyqtSignal(str)
    finished_ok = pyqtSignal()
    failed = pyqtSignal(str)

    def start(self):
        threading.Thread(target=self._run, daemon=True).start()

    def _run(self):
        try:
            dev, serial = _dfu_serial()
            cpid = _serial_field(serial, "CPID")
            entry = identify(f"0x{cpid.lower()}", _serial_field(serial, "BDID"))
            ecid_hex = _serial_field(serial, "ECID")
            ecid = int(ecid_hex, 16) if ecid_hex else None

            ibec_path = ibec_path_for(entry[1])
            self.step.emit(f"Uploading {ibec_path.name}...")
            dfu_upload(dev, ibec_path.read_bytes())
            self.step.emit("Booting iBEC...")
            dfu_boot(dev)

            self.step.emit("Waiting for recovery mode...")
            irecv = IRecv(ecid=ecid, is_recovery=True, timeout=60)

            self.step.emit("Sending obliteration commands...")
            for cmd in ("setenv oblit-inprogress 5",
                        "setenv auto-boot true",
                        "saveenv"):
                irecv.send_command(cmd)
            try:
                irecv.send_command("reboot")
            except Exception:
                pass
            self.finished_ok.emit()
        except Exception as e:
            self.failed.emit(str(e))


class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("usbobliter8 v1.0.0")
        self.resize(400, 280)
        self._busy = False
        self._build_ui()
        screen = QApplication.primaryScreen().availableGeometry()
        self.move((screen.width() - self.width()) // 2,
                  (screen.height() - self.height()) // 2)
        self._detector = Detector()
        self._detector.detected.connect(self._on_detected)

    def _build_ui(self):
        central = QWidget()
        self.setCentralWidget(central)
        root = QVBoxLayout(central)
        root.setContentsMargins(28, 28, 28, 28)
        root.setSpacing(6)
        root.addStretch(1)

        self.name_lbl = self._mk_label(20, True, "Waiting for device...")
        root.addWidget(self.name_lbl)

        self.pwnd_lbl = self._mk_label(13, True, " ")
        root.addWidget(self.pwnd_lbl)

        self.status_lbl = self._mk_label(-1, False, "Ready")
        self.status_lbl.setStyleSheet(f"color:{MUTED};")
        root.addWidget(self.status_lbl)

        root.addSpacing(14)
        self.run_btn = QPushButton("Obliter8!")
        self.run_btn.setMinimumWidth(180)
        self.run_btn.setDefault(True)
        self.run_btn.setEnabled(False)
        self.run_btn.clicked.connect(self._start)
        root.addWidget(self.run_btn, alignment=Qt.AlignCenter)
        root.addStretch(2)

    @staticmethod
    def _mk_label(size, bold, text):
        lbl = QLabel(text)
        lbl.setAlignment(Qt.AlignCenter)
        f = lbl.font()
        if size > 0:
            f.setPointSize(size)
        f.setBold(bold)
        lbl.setFont(f)
        return lbl

    def _show_device(self, name, pwnd_text, name_color, pwnd_color, can_run):
        self.name_lbl.setText(name)
        self.name_lbl.setStyleSheet(f"color:{name_color};" if name_color else "")
        self.pwnd_lbl.setText(pwnd_text or " ")
        self.pwnd_lbl.setStyleSheet(f"color:{pwnd_color};" if pwnd_color else "")
        self.run_btn.setEnabled(can_run and not self._busy)

    def _on_detected(self, info):
        if info is None:
            self._show_device("Waiting for device...", " ", MUTED, MUTED, False)
            return
        cpid, bdid, pwnd = info
        cpid_key = f"0x{cpid.lower()}" if cpid else None
        pwnd_text = "PWNED" if pwnd else "Not PWNED"
        pwnd_color = GREEN if pwnd else RED
        entry = identify(cpid_key, bdid)
        if entry is None:
            label = (f"Unsupported (CPID:{cpid})" if cpid_key not in SUPPORTED_CPIDS
                     else f"Unknown board (CPID:{cpid} BDID:{bdid})")
            self._show_device(label, pwnd_text, RED, pwnd_color, False)
            return
        can_run = pwnd and ibec_path_for(entry[1]).is_file()
        self._show_device(entry[0], pwnd_text, "", pwnd_color, can_run)

    def _start(self):
        self._detector._paused = True
        self._busy = True
        self.run_btn.setEnabled(False)
        self.status_lbl.setText("Working...")
        self._worker = Obliter8Worker()
        self._worker.step.connect(self.status_lbl.setText)
        self._worker.finished_ok.connect(lambda: self._finish("Done"))
        self._worker.failed.connect(lambda m: self._finish("Failed", m))
        self._worker.start()

    def _finish(self, status, msg=None):
        self._busy = False
        self._detector._paused = False
        self.status_lbl.setText(status)
        QTimer.singleShot(3000, lambda: self.status_lbl.setText("Ready"))
        if msg:
            QMessageBox.critical(self, "usbobliter8", msg)

    def closeEvent(self, event):
        self._detector._stop = True
        event.accept()


def main():
    app = QApplication(sys.argv)
    win = MainWindow()
    win.show()
    sys.exit(app.exec_())


if __name__ == "__main__":
    main()
