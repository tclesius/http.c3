import std::io;
import http;
import url;

fn void main()
{
	Response res = http::get("http://jsonip.com")
	io::printfn(" Body:\n  %s", res.text());
}