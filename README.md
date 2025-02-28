# Honeybadger - a Personal Device Audit tool for ISO27001

Make your computer as tough as a honeybadger. And that is tough. Check this video...

[![YouTube](http://i.ytimg.com/vi/4r7wHMg5Yjg/hqdefault.jpg)](https://www.youtube.com/watch?v=4r7wHMg5Yjg)

## Usage on Linux and macOS

open a terminal and execute the following.

```
git clone https://github.com/wearetechnative/honeybadger
cd honeybadger
./RUNME.sh audit
```

## Usage on Windows

- download honeybadger as a zip-file from https://github.com/wearetechnative/honeybadger/archive/refs/heads/main.zip
- extract the zip-file 
- open a powershell as admin
- change you directory to the honeybadger directorty you've extracted.
- check copy full path of the RUNME.ps1 file
- `powershell -ExecutionPolicy Bypass -File $FULL_PATH_OF_RUNME.ps1`
- ./RUNME.ps1

## The results files

When the script has run successfully a zip or tarball with findings is stored in the
same directory. It looks like this: `honeybadger-pim-28-02-2025.tar.bz2`. Send
this file to the CISO or the person who asked you to do run this audit script.

The output is available in a bz2 file.

## Credits

- [Video Embedding](https://githubvideo.com/)
- [Lynis](https://cisofy.com/lynis/)
- [Lynis Report Converter](https://github.com/d4t4king/lynis-report-converter)
- [Lynis Report Converter Dockerfile](https://github.com/oceanlazy/docker-lynis-report-converter)

---

© Technative 2024-2025
