import std::io;
import http;

fn void main()
{
	io::printfn("\nRequest:");

	Request req = http::get("http://localhost:8000/")
		.header("Content-Type", "application/json; charset=utf-8")
		.header("Authorization", "Bearer token123")
		.cookie({.name="secret", .value="abcdefg", .path="/", .domain="localhost"})
		.cookie({.name="secret2", .value="abcdefgh", .path="/", .domain="localhost"});
	
	io::printfn(" HTTP Version: %s", req.protocol);
	io::printfn(" Headers:");
	foreach(header : req.headers)
	{
		io::printfn("   %s: %s", header.key, header.value);
	}
	io::printfn(" Cookies:");
	foreach(cookie : req.jar.cookies.value_tlist())
	{
		io::printfn("   %s", cookie.to_string());
	}

	// Print the body
	//io::printfn(" Body:\n  %s", req.body);	


	Response res = req.send();
	// Print status code, protocol, and status message
	io::printfn("\nResponse:");
	io::printfn(" HTTP Version: %s", res.protocol);
	io::printfn(" Status Code: %d", res.status_code);
	io::printfn(" Status Message: %s", res.status_message);

	// Print all headers
	io::printfn(" Headers:");
	foreach(header : res.headers)
	{
		io::printfn("   %s: %s", header.key, header.value);
	}
	
	io::printfn(" Cookies:");
	foreach(cookie : res.jar.cookies.value_tlist())
	{
		io::printfn("   %s", cookie.to_string());
	}
	//Print the body
	io::printfn(" Body:\n  %s", res.body);
	//res.json()!!;
}