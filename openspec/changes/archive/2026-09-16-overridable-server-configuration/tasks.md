## 1. Precedence

- [x] 1.1 Capture which settings the environment supplied before sourcing
- [x] 1.2 Source the config file, then restore the environment's values over it
- [x] 1.3 Apply built-in defaults only to settings neither source supplied
- [x] 1.4 Treat an explicitly empty environment value as supplied, not as unset

## 2. Naming a config file

- [x] 2.1 `load_server_config` accepts an explicit path and skips the search
- [x] 2.2 `--config <file>` on `submit`, passed through to the loader
- [x] 2.3 `HONEYBADGER_CONFIG` does the same from the environment
- [x] 2.4 A named file that does not exist is an error, not a silent fallback

## 3. Reporting

- [x] 3.1 Report which file was loaded, as it already does
- [x] 3.2 Name the settings the environment supplied, so an override is visible
- [x] 3.3 Report when no file was found and defaults are in use

## 4. Tests

- [x] 4.1 An environment variable survives the config file
- [x] 4.2 A setting absent from the environment takes the file's value
- [x] 4.3 A setting in neither takes the built-in default
- [x] 4.4 An explicitly empty environment value is not replaced by a default
- [x] 4.5 `--config` loads the named file and ignores the search order
- [x] 4.6 `HONEYBADGER_CONFIG` does the same
- [x] 4.7 A named file that does not exist fails and names the path
- [x] 4.8 `DRY_RUN=true` from the environment beats `DRY_RUN=false` in the file

## 5. Docs

- [x] 5.1 `README.md`: the precedence, `--config`, and `HONEYBADGER_CONFIG`
- [x] 5.2 `.honeybadger.conf.example`: note that the environment wins
- [x] 5.3 `CHANGELOG.md` under NEXT VERSION
