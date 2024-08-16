module http;
import url;
import std::collections::map;
import std::collections::object;
import std::collections::list;
import std::encoding::json;
import std::net::tcp;
import std::io;
import std::time::datetime;


struct Header {
    String key;
    String value;
}

struct Response { // maybe put byte writer and byte reader in here
    CookieJar cookies;
    String protocol;
    uint code;
    String status;
    String body; 
    List(<Header>) headers;
}

struct Request 
{
    CookieJar cookies;
    String protocol;
    String method;
    Url url;
    List(<Header>) headers;
}

struct Cookie
{
    String name;
    String value;
    // String path;
    // DateTime expires;
    // bool secure;
    // bool http_only;
}

def CookieJar = HashMap(<String, List(<Cookie>)>);



//// Response methods

fn Object*! Response.json(&self)
{
    return json::parse_string(self.body);
}

fn String Response.text(&self)
{
    return self.body;
}

////

fn Request Request.header(&self, String key, String value)
{
    self.headers.push({.key=key, .value=value});
    return *self; // TODO: should pass by reference 
}

fn Response Request.send(&self) // exec would be a good name too 
{
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


    foreach(header: self.headers)
    {
        //io::printfn("%s %s", header.key, header.value);
        w.write(header.key.concat(": ").concat(header.value).concat("\n"))!!;
    }
    w.write("\r\n\r\n")!!;
    
    if (try usz bytes_written = sock.write(w.str_view())){
        io::printfn("\nSend: %d bytes\n", bytes_written);
    };
    //io::printfn("%s", w.str_view());
    
    w.destroy()!!;
    w.temp_init();
    char[4096] buffer;
    while(try usz bytes_received = sock.read(buffer[:buffer.len]) && bytes_received > 0)
    {
        io::printfn("\nRecieved: %d bytes\n", bytes_received);
        w.write(buffer[:buffer.len])!!;
        if(((String)buffer[:buffer.len]).contains("\r\n\r\n")) // TODO: body is not optional so if not found panic
        {
            break;
        };
        
    }

    String[] data = w.str_view().split("\r\n\r\n");
    //io::printfn("%d", data.len);
    res.body = data[1];
    
    String[] message;
    if((message = data[0].split("\n")) && message.len > 1)
    {
        String[] response_status = message[0].split(" ");
        // TODO: response status can be malformed should 
        res.protocol = response_status[0];
        res.code = response_status[1].to_uint()!!;
        res.status = response_status[2];
        // parsing response headers 
        //foreach(h : message[1:message.len-1])
        //{
            //String[] header = h.split(":");
            //String key = header[0].strip(" ").strip_end(" ");
            //String value = header[1].strip(" ").strip_end(" ");
            //if (key == "Set-Cookie") // TODO: Header is case insensitive
            //{
            //    
            //    // a cookie definition starts with a key value pair
            //    String[] cookie_data = value.split(";");
            //    // TODO: foreach over all cookie attributes
            //    String[] name_value = cookie_data[0].strip(" ").strip_end(" ").split("=");
            //    
            //    
            //    if (try list = self.cookies[self.url.host]) 
            //    {
            //        list.push({.name=name_value[0], .value=name_value[1]}); // TODO: must replace cookie values with same name
            //    }
            //    else
            //    {
            //        self.cookies[self.url.host] = {};
            //        self.cookies[self.url.host]!!.push({.name=name_value[0], .value=name_value[1]}); // TODO: must replace cookie values with same name
            //    } 
            //    
            //}

            //res.headers.push(
            //    {
            //        .key=key,
            //        .value=value
            //    }
            //);
        //}
    }
    return res;
}

fn Request request(String method, String url)
{
    Url req_url = url::parse(url)!!;
    list::List(<Header>) headers;
    headers.new_init();
    
    headers.push({.key="Connection", .value="keep-alive"}); // Connection can be keep-alive or close 
    headers.push({.key="Host", .value=req_url.host});
    
    Request req = {
        .protocol="HTTP/1.1", // TODO: should not be hardcoded ithink
        .method=method,
        .url=req_url,
        .headers=headers,
    };
    return req;
}

fn Request get(String url) { return request("GET", url); }
fn Request options(String url) { return request("OPTIONS", url); }
fn Request head(String url) { return request("HEAD", url); }
fn Request post(String url) { return request("POST", url); }
fn Request put(String url) { return request("PUT", url); }
fn Request patch(String url) { return request("PATCH", url); }
fn Request delete(String url) { return request("DELETE", url); }