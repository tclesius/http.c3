## Goals

- [x] Implement a method/lambda to handle the response body as JSON.
- [x] Implement support for HTTP headers.
- [x] Implement cookie handling.
- [x] Add support for request bodies (with various encodings).
- [x] Support receiving responses with `Transfer-Encoding: Chunked`.
- [ ] Add support for sending requests with `Transfer-Encoding: Chunked`.
- [ ] Implement support for handling redirects (with an option to allow or disallow redirects) and maintain a history as `List(Response)`.
- [ ] Implement requests through HTTP proxies.
- [ ] Support sending POST requests with URL-encoded data.
- [ ] Support URL-encoding `params` (key-value pairs) and appending them as query parameters.
- [ ] Support sending `data` (key-value pairs) as URL-encoded body content (`application/x-www-form-urlencoded`) or as plain text.
- [ ] Implement default cookie management (set default path/host even if not sent by the server).
- [ ] Add support for socket timeouts.
- [ ] Write comprehensive tests.
- [ ] Implement session management (see [Python Requests Sessions](https://docs.python-requests.org/en/latest/user/advanced/)).
- [ ] Build requests individually and send them when ready.
- [ ] Test downloading files.
