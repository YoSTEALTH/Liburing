import socket
import liburing


def test_define():
    liburing.AF_UNIX == socket.AF_UNIX
    liburing.AF_INET == socket.AF_INET
    liburing.AF_INET6 == socket.AF_INET6
