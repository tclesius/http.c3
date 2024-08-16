import std::io;
import http;

fn void main()
{
	Response r = http::get("http://jsonip.com")
		.header("Content-Type", "application/json")
		.header("Authorization", "Bearer token123")
		.send();

	// Print status code, protocol, and status message
	io::printfn("HTTP Version: %s", r.protocol);
	io::printfn("Status Code: %d", r.code);
	io::printfn("Status Message: %s", r.status);

	// Print all headers
	io::printfn("Headers:");
	foreach(header : r.headers)
	{
		io::printfn("  %s: %s", header.key, header.value);
	}

	// Print the body
	io::printfn("Body:\n %s", r.body);
}
