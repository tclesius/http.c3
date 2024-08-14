module http;
import url;
import std::collections::map;
import std::collections::object;
import std::encoding::json;
import std::net::tcp;
import std::io;

struct Response {
    uint status;
    String body;
    HashMap(<String, String>) headers;
}

fn Object*! Response.json(Response* self)
{
    return json::parse_string(self.body);
}
fn String Response.text(Response* self)
{
    return self.body;
}

fn Response! request(String method, String url, args...)
{
    Response res;
    Url! purl = url::parse(url);

    if (catch err = purl)
    {
        // throw error
    }

    TcpSocket! sock = tcp::connect(purl.host, purl.port,{});
    defer sock.destroy()!!;
    if (catch err = sock)
	{
		io::printfn("Error when trying to connect to host %s", err);
		return err?;
	}
    
    char[] http_request = string::new_format("%s %s HTTP/1.1\r\nHost: %s \r\nConnection: close\r\n\r\n", method, purl.path!!, purl.host!!);
	usz! bytes_written = sock.write(http_request);
	if (catch err = bytes_written)
	{
		io::printfn("Error when trying to write to socket %s", err);
		return err?;
	}
	
 	char[4096] buffer;
    usz! bytes_received = sock.read(buffer[:buffer.len]);
	String text = (String) buffer[:buffer.len];

	res.body = text.split("\r\n\r\n")[1];
    return res;
}

fn Response! get(String url, args...)
{
    return request("GET", url, ...args);
} 

fn Response! options(String url, args...)
{
    return request("OPTIONS", url, ...args);
}

fn Response! head(String url, args...)
{
    return request("HEAD", url, ...args);
}

fn Response! post(String url, args...)
{
    return request("POST", url, ...args);
} 

fn Response! put(String url, args...)
{
    return request("PUT", url, ...args);
} 

fn Response! patch(String url, args...)
{
    return request("PATCH", url, ...args);
} 

fn Response! delete(String url, args...)
{
    return request("DELETE", url, ...args);
} 