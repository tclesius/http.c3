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

struct Response { // maybe put byte writer and byte reader in here
    String protocol;
    uint code;
    String status;
    String body; 
    List(<Header>) headers;
}

struct Request 
{
    String protocol;
    String method;
    Url url;
    List(<Header>) headers;
}


////

fn Object*! Response.json(Response* self)
{
    return json::parse_string(self.body);
}

fn String Response.text(Response* self)
{
    return self.body;
}

////

fn Request Request.header(&self, String key, String value)
{
    self.headers.push({.key=key, .value=value});
    return *self; // TODO: should pass by reference 
}

fn Response Request.send(&self)
{
    self.protocol = "HTTP/1.1";

    Response res;
    ByteWriter w;
    w.temp_init();
    
    TcpSocket! sock = tcp::connect(self.url.host, self.url.port, {});    
    defer sock.destroy()!!;

    w.write(self.method)!!;
    w.write(" ")!!;
    w.write(self.url.path)!!;
    w.write(" ")!!;
    w.write(self.protocol)!!;
    w.write("\r\n")!!;
    
    // TODO: ensure in some way that these are in the request headers
    self.headers.push({.key="Connection", .value="close"}); // Connection can be keep-alive or close 
    self.headers.push({.key="Host", .value=self.url.host});

    foreach(header: self.headers)
    {
        //io::printfn("%s %s", header.key, header.value);
        w.write(header.key.concat(": ").concat(header.value).concat("\n"))!!;
    }
    w.write("\r\n\r\n")!!;
    
    io::printfn("%s", w.str_view());
    
    usz! bytes_written = sock.write(w.str_view());
	
    //io::printfn("%d %s", bytes_written!!, w.str_view());

    w.destroy()!!;
    w.temp_init();
    char[4096] buffer;
    while(try usz bytes_received = sock.read(buffer[:buffer.len]) && bytes_received > 0)
    {
        w.write(buffer[:buffer.len])!!;
        if(((String)buffer[:buffer.len]).contains("\r\n\r\n")) // body is not optional so if not found panic
        {
            break;
        };
        io::printfn("Recieved: %d bytes", bytes_received);
    }

    String[] data = w.str_view().split("\r\n\r\n");
    res.body = data[1];
    
    String[] message;
    if((message = data[0].split("\n")) && message.len > 1)
    {
        String[] response_status = message[0].split(" ");
        // TODO: response status can be malformed should 
        res.protocol = response_status[0];
        res.code = response_status[1].to_uint()!!;
        res.status = response_status[2];
        
        foreach(h : message[1:message.len-1])
        {
            String[] key_value = h.split(":");
            self.headers.push(
                {
                    .key=key_value[0].strip(" ").strip_end(" "), 
                    .value=key_value[1].strip(" ").strip_end(" ")
                }
            );
        }
    }
    return res;
}

fn Request request(String method, String url)
{
    Url req_url = url::parse(url)!!;
    list::List(<Header>) req_headers;
    req_headers.new_init();
    Request req = {
        .method=method,
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