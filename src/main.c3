import std::io;
import std::net;
import std::net::tcp;
import std::encoding::json;
import std::collections::object;
import std::time, libc, std::os;
import url;

fn void main()
{
	// read file raw
	
	// File! file  = file::open("project.json", "r");
	// defer (void) file.close();
	// if (catch err = file)
	// {
	// 	io::printfn("Error in file::open %s", err);
	// 	return;
	// }
	// Allocator alloc = allocator::heap();
	// usz len = file.seek(0, END)!!;
	// file.seek(0, SET)!!;
	// char* data = allocator::malloc_try(alloc, len)!!;
	// defer catch allocator::free(alloc, data);
	// usz read = 0;
	// while (read < len)
	// {
	// 	read += file.read(data[read:len - read])!!;
	// }
	// io::printfn("%s", data[:len]);

	// read file and parse json

	//char[]! text = file::load_new("simple.json");
	//if (catch err = text)
	//{
	//	io::printfn("Error in file::open %s", err);
	//	return;
	//}
	//io::printfn("%s", text);
	//
	//Object* json = json::parse_string((String) text)!!;
	//io::printfn(json.get_string("version")!!);
	

	// read chars raw from web
	//TcpSocket! sock = tcp::connect("jsonip.com", 80,{});
	//defer sock.destroy()!!;
	//if (catch err = sock)
	//{
	//	io::printfn("Error when trying to connect to host %s", err);
	//	return;
	//}
	//char[] http_request = "GET / HTTP/1.1\r\nHost: jsonip.com\r\nConnection: close\r\n\r\n";
	//usz! bytes_written = sock.write(http_request);
	//if (catch err = bytes_written)
	//{
	//	io::printfn("Error when trying to write to socket %s", err);
	//	return;
	//}
	//
 	//char[4096] buffer;
    //usz! bytes_received = sock.read(buffer[:buffer.len]);  // No need to dereference buffer
	//String text = (String) buffer[:buffer.len];

	//io::printfn("\n %s \n", text);

	//String[] response = text.split("\r\n\r\n");
	// io::printfn("%s", response[1]);
	//Object* json = json::parse_string(response[1])!!;
	//io::printfn(json.get_string("ip")!!);
    String url = "http://example.com";
	Url! parsed = url::parse(url);
    if (catch err = parsed)
    {
        io::printfn("Error Parsing the url %s", err);
    }
    else
    {
		io::printfn("Scheme: %s", parsed.scheme);
        io::printfn("Host: %s", parsed.host);
        io::printfn("Port: %d", parsed.port);
        io::printfn("Path: %s", parsed.path);
        io::printfn("Query: %s", parsed.query);
        io::printfn("Fragment: %s", parsed.fragment);
		io::printfn("Userinfo: %s", parsed.userinfo);
    }
}