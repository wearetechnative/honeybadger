## 1. Bundle Python Converter

- [x] 1.1 Download `lynis_report_converter.py` from `wearetechnative/lynis-report-converter` repo and place it at `lib/lynis_report_converter.py`
- [x] 1.2 Make `lib/lynis_report_converter.py` executable (`chmod +x`)

## 2. Configuration

- [x] 2.1 Add `USE_DOCKER_CONVERTER=false` with descriptive comment to `.honeybadger.conf.example`
- [x] 2.2 Load `USE_DOCKER_CONVERTER` from config in `RUNME.sh` (default to `false` if unset)

## 3. Update RUNME.sh Audit Function

- [x] 3.1 Make `checkdeps "docker"` conditional — only check when `USE_DOCKER_CONVERTER=true`
- [x] 3.2 Add `checkdeps "python3"` when `USE_DOCKER_CONVERTER` is not `true`
- [x] 3.3 Replace the Docker converter block (image check + `docker run`) with Python script invocation as the default path
- [x] 3.4 Keep Docker converter logic in an `else` branch for when `USE_DOCKER_CONVERTER=true`

## 4. Verification

- [x] 4.1 Test that `./RUNME.sh audit` runs with Python converter (no Docker required)
- [x] 4.2 Test that `USE_DOCKER_CONVERTER=true` falls back to Docker converter
