## Goals
- [x] Response Body json method / lambda 
- [~] Headers implementieren
- [~] Cookies implementieren
- [~] Request body hinzufuegen (verschiedene encodings)
- [~] Transfer Encoding Chunked empfangen unterstuetzen
- [ ] Transfer Encoding Chunked senden unterstuetzen
- [ ] Redirects unterstützen (allow_redirects) / History -> List(Response) aufbauen
- [ ] Requests über http proxies implementieren
- [ ] POST urlencoded data
- [ ] Parameter: params key value werden urlencoded als query parameter angehaengt
- [ ] Parameter: data (key value) werden urlencoded an body angehaengt : application/x-www-form-urlencoded oder als txt
- [ ] Cookie management - default path / default host setzen auch wenn keiner gesendet
- [ ] Socket Timeout einbauen
- [ ] Tests schreiben
- [ ] Sessions implementieren siehe: https://docs.python-requests.org/en/latest/user/advanced/
- [ ] Requests einzeln bauen und diese dann senden vielleicht einbauen 
- [ ] Download von files testen
 
## Goals Advanced
- [ ] Parameter: file: support for multipart/form-data
- [ ] Websockets implementieren
- [ ] Transfer Encoding gzip empfangen unterstuetzen
- [ ] Transfer Encoding gzip senden unterstuetzen


## Quick wins
- [x] curl -v jsonip.com debug messages
- [x] User-Agent: c3c/http in request header hinzufuegen
- [z] Rename Status code and Status message 

## Other Libs
- [ ] tqdm like lib