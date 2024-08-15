module http;
import url;
import std::collections::map;
import std::collections::object;
import std::collections::list;
import std::encoding::json;
import std::net::tcp;
import std::io;


struct Header {
    String key;
    String value;
}

struct Response {
    uint status;
    String body;
    List(<Header>) headers;
}

fn Object*! Response.json(Response* self)
{
    return json::parse_string(self.body);
}

fn String Response.text(Response* self)
{
    return self.body;
}

struct Request 
{
    String method;
    Url url;
    List(<Header>) headers;
}

fn Request Request.header(&self, String key, String value)
{
    self.headers.push({.key=key, .value=value});
    return *self; // TODO: should pass by reference 
}

fn Response! Request.send(&self)
{
    TcpSocket! sock = tcp::connect(self.url.host, self.url.port,{});
    defer sock.destroy()!!;
    if (catch err = sock)
	{
		io::printfn("Could not connect to host");
		return err?;
	}
    // Connection can be keep-alive or close
    char[] http_request = string::new_format("%s %s HTTP/1.1\r\nHost: %s \r\nConnection: close\r\n\r\n", self.method, self.url.path, self.url.host);
	usz! bytes_written = sock.write(http_request);
	if (catch err = bytes_written)
	{
		io::printfn("Could not send data to host");
		return err?;
	}
	

    ByteWriter w;
    w.new_init();
    char[4096] buffer;
    
    while(try usz bytes_received = sock.read(buffer[:buffer.len]) && bytes_received > 0)
    {
        w.write(buffer[:buffer.len])!!;
        if(((String)buffer[:buffer.len]).contains("\r\n\r\n"))
        {
            io::printfn("Headers:\n%s\n", w.str_view());
            io::printfn("Headers Length: %d bytes\n", w.str_view().len);
            break;
        };
        io::printfn("Recieved: %d bytes", bytes_received);
    }

    String text = w.str_view();
    Response! r = {
        .body=text.split("\r\n\r\n")[1]
        // TODO write something that parses headers and put them in here 
        // TODO write something that parses the statuscode and put it in here
    };
    return r;
}

fn Request request(String method, String url)
{
    Url req_url = url::parse(url)!!;
    list::List(<Header>) req_headers;
    req_headers.new_init();
    Request req = {
        .method = method, 
        .url=req_url,
        .headers=req_headers,
    };
    return req;
}

fn Request get(String url)
{
    return request("GET", url);
} 

fn Request options(String url)
{
    return request("OPTIONS", url);
}

fn Request head(String url)
{
    return request("HEAD", url);
}

fn Request post(String url)
{
    return request("POST", url);
} 

fn Request put(String url)
{
    return request("PUT", url);
} 

fn Request patch(String url)
{
    return request("PATCH", url);
} 

fn Request delete(String url)
{
    return request("DELETE", url);
}