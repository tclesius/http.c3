import std::io;
import http;

fn void main()
{
	Response! r = http::get("http://jsonip.com")
		.header("Content-Type", "application/json")
		.header("Authorization", "Bearer token123")
		.send();

	io::printfn(r.json().get_string("ip")!!);
}