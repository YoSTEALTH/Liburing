import liburing

for k, v in liburing.probe().items():
    print(k, v)
