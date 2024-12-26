import http;
import url;

import std::io;


fn void main()
{
	Response res = http::get("http://jsonip.com");
	io::printfn(" Body:\n  %s", res.text());
}
