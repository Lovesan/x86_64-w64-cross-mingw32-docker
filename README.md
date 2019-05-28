# GCC cross-compiler for MinGW environment - Docker files

## Docker hub repo

You can obtain an image from Docker Hub:

```docker pull love5an/x86_64-w64-cross-mingw32:latest```

You can also try specific version:

```docker pull love5an/x86_64-w64-cross-mingw32:9.1.0```

## Contents

Images are based on corresponding official **GCC** images, e.g. ```gcc:9.1.0```

Official images use Debian Linux.

All the executables as well as MinGW runtime are placed into 
```/opt/x86_64-w64-cross-mingw32``` directory.
```PATH``` is modified correspondingly.

