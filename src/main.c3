import std::io;
import http;
import url;

fn void main()
{
	Response res = http::get(
						.url="http://localhost:8000/echo",
						.headers={
							{"Content-Type", "application/json; charset=utf-8"},
							{"Authorization", "Bearer token123"},
							//{"Transfer-Encoding", "chunked"}
						},
						.cookies={
							{.name="secret", .value="abcdefg", .path="/", .domain="localhost"},
							{.name="secret2", .value="abcdefgh", .path="/", .domain="localhost"}
						},
						.body="{\"hello\":\"world\"}",
						.params={{"hello", "world"}},
						.stream=false
					);
	//io::printfn(" HTTP Version: %s", req.protocol);
	//io::printfn(" Headers:");
	//foreach(header : req.headers)
	//{
	//	io::printfn("   %s: %s", header.key, header.value);
	//}
	//io::printfn(" Cookies:");
	//foreach(cookie : req.jar.cookies.value_tlist())
	//{
	//	io::printfn("   %s", cookie.to_string());
	//}

	// Print the body
	//io::printfn(" Body:\n  %s", req.body);	
	// Print status code, protocol, and status message
	io::printfn("\nResponse:");
	io::printfn(" HTTP Version: %s", res.protocol);
	io::printfn(" Status Code: %d", res.status_code);
	io::printfn(" Status Message: %s", res.status_message);

	// Print all headers
	//io::printfn(" Headers:");
	//foreach(header : res.headers)
	//{
	//	io::printfn("   %s: %s", header.key, header.value);
	//}
	//
	//
	//foreach(ix, cookie : res.jar.cookies.value_tlist())
	//{
	//	if (ix == 0)
	//	{
	//		io::printfn(" Cookies:");
	//	}
	//	io::printfn("   %s", cookie.to_string());
	//}
	//
	//while(try chunk = res.content_iter.next(7))
	//{
	//	io::printfn("   %s", chunk);
	//}
	//Print the body
	io::printfn(" Body:\n  %s", res.text());
	
	//res.json()!!;

	//io::printn(url::unquote_plus(url::quote_plus("Hello World!")));

}