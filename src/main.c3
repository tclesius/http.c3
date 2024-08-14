import std::io;
import http;

fn void main()
{
	Response r = http::get("http://jsonip.com")!!;
	io::printfn(r.json().get_string("ip")!!);
}