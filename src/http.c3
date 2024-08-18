module http;
import url;
import std::collections::map;
import std::collections::object;
import std::collections::list;
import std::encoding::json;
import std::net::tcp;
import std::io;
import std::time::datetime;

struct Header 
{
    String key;
    String value;
}

struct Response 
{
    CookieJar jar;
    String protocol;
    uint status_code;
    String status_message;
    String body;
    List(<Header>) headers;
}

struct Request 
{
    CookieJar jar;
    String protocol;
    String method;
    Url url;
    String body;
    List(<Header>) headers;
}

struct Cookie 
{
    String name;
    String value;
    String domain; // if starting with . for all subdomains valid
    String path;
    String expires;
    String max_age;
    String same_site;
    // flags    
    bool secure;
    bool http_only;
    
}

struct CookieJar {
    HashMap(<String, Cookie>) cookies;
}

//// CookieJar methods

fn void CookieJar.set_cookie(&self, Cookie cookie) 
{
    DString key;
    key.new_init();
    key.appendf("%s,%s,%s", cookie.name, cookie.domain, cookie.path);
    self.cookies[key.str_view()] = cookie;
}

fn Cookie! CookieJar.get_cookie(&self, String name , String domain, String path) 
{
    DString key;
    key.new_init();
    key.appendf("%s,%s,%s", name, domain, path);
    return self.cookies[key.str_view()];
}

//// Response methods

fn Object*! Response.json(&self) 
{
    return json::parse_string(self.body);
}

fn String Response.text(&self) 
{
    return self.body;
}

//// Cookie methods
fn String Cookie.to_string(&self)
{
    DString result;
    result.new_init();
    result.appendf(
        "<Cookie %s=%s; Domain=%s; Path=%s; Expires=%s; Max-Age=%s; SameSite=%s; Secure=%b; HttpOnly=%b >",
        self.name,
        self.value,
        self.domain,
        self.path,
        self.expires,
        self.max_age,
        self.same_site,
        self.secure,
        self.http_only
    );
    return result.str_view();
}

fn Cookie parse_set_cookie(String value)
{
    Cookie cookie;
    // iterate over every attribute a cookie can set
    foreach(ix, attribute: value.trim().split(";"))
    {
        // parse key value attributes
        if(attribute.contains("="))
        {
            String[] kv = attribute.trim().split("=");
            // the first name value is always the cookie name and cookie value identifier
            if(ix == 0)
            {
                cookie.name = kv[0];
                cookie.value = kv[1];
            } 
            else
            {
                switch(attribute.temp_ascii_to_lower())
                {
                    case "domain": cookie.domain = kv[1];
                    case "path": cookie.path = kv[1];
                    case "expires": cookie.expires = kv[1];
                    case "max-age": cookie.max_age = kv[1];
                    case "same-site": cookie.same_site = kv[1];
                }
            }
            continue;
        }
        // parse flag attributes
        switch(attribute.temp_ascii_to_lower())
        {
            case "secure": cookie.secure = true;
            case "httponly": cookie.http_only = true;
        }
    }
    return cookie;
}

fn void recieve_response(TcpSocket socket, Response* res)
{
    
    ByteWriter writer; 
    writer = *writer.temp_init();
    char[4096] buffer;
    
    // read header and maybe part of body from the socket
    while(try bytes = socket.read(buffer[:buffer.len]) && bytes > 0) 
    {
        writer.write(buffer[:buffer.len])!!;
        buffer = {}; // clear the temporary buffer
        // Read data from the socket until "\r\n\r\n" marker is encountered.
        if (writer.str_view().contains("\r\n\r\n")){ break; }
    }

    String[] data = writer.str_view().split("\r\n\r\n");
    
    // parse status line and headers
    String header = data[0];
    String body = data[1];
    uint content_length = 0;
    
    foreach(ix, line: header.split("\r\n"))
    {
        if(ix == 0)
        {
            // parse status line
            String[] status_line = line.trim().split(" ", 3);
            res.protocol = status_line[0];
            res.status_code = status_line[1].to_uint()!!;
            res.status_message = status_line[2];
        }   
        else
        {
            // parse headers
            String[] kv = line.trim().split(":", 2);
            res.headers.push({.key=kv[0], .value=kv[1]});
            
            String lower_key = kv[0].temp_ascii_to_lower();
            
            // if content-length header - save value
            if ("content-length" == lower_key)
            {
                content_length = kv[1].to_uint()!!;
            }
            else if("set-cookie" == lower_key)
            {
                Cookie cookie = parse_set_cookie(kv[1]); // TODO: domain and path has default if missing!
                res.jar.set_cookie(cookie);
            }
        }
    }
    
    // calculate the remaining data to be send 
    int remaining = content_length - body.len;

    //io::printfn("Remaining: %d", remaining);
    //io::printfn("%d", body.len);
    //io::printfn("%d", content_length);
    
    if( remaining < 0 )
    {
        res.body = body;
        return;
    }
    // TODO: @optimization: just read remaining bytes not static 4096 bytes
    // read the remaining body from the socket
    while(try bytes = socket.read(buffer[:buffer.len]) && bytes > 0) 
    {
        //io::printfn("Remaining %d", remaining);
        writer.write(buffer[:buffer.len])!!;
        remaining -= (uint) bytes;
        
        buffer = {};
        if( remaining < 0 )
        {
            res.body = body;
            return;
        }   
    }
}

fn void send_request(TcpSocket socket, Request* req)
{
    DString data;
    data.temp_init();
    // write request line
    data.appendf("%s %s %s\r\n", req.method, req.url.path, req.protocol);
    // write request headers
    foreach(header: req.headers)
    {
        data.appendf("%s: %s\r\n", header.key, header.value);
    }
    // write content-length if body present
    if(req.body.len > 0)
    {
        data.appendf("Content-Length: %d", req.body.len);
    }
    // write relevant cookie headers
    foreach(ix, cookie: req.jar.cookies.value_tlist())
    {   
        if (cookie.domain == req.url.host && cookie.path == req.url.path) // @TODO domain != host
        {
            if(ix == 0)
            {
                data.appendf("Cookie: ");
            } 
            else
            {
                data.appendf("; ");
            }
            data.appendf("%s=%s", cookie.name, cookie.value);
        }
    }
    data.appendf("\r\n\r\n");
    data.appendf(req.body);
    //io::printfn(data.str_view());
    // @TODO Calculate the content-length and add Header
    // @TODO write the request body
    int last_pos = 0;
    String buffer = data.str_view();
    while(try bytes = socket.write(buffer[last_pos:buffer.len]) && bytes > 0) 
    {
        last_pos += (uint) bytes;
        if( last_pos >= req.body.len ){ break; }   
    }
    //socket.write_all(data.str_view())!!;
}

fn Response request(String method, String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{
    Url req_url = url::parse(url)!!;
    Response res;
    List(<Header>) headers_;
    headers_.new_init_with_array(headers);

    headers_.push({.key="Connection", .value="keep-alive"});
    headers_.push({.key="Host", .value=req_url.host});
    
    CookieJar jar;
    foreach(cookie: cookies)
    {
        jar.set_cookie(cookie);
    }
    
    Request req = {
        .protocol="HTTP/1.1",
        .method=method,
        .url=req_url,
        .headers=headers_,
        .body=body,
        .jar=jar
    };

    TcpSocket! sock = tcp::connect(req.url.host, req.url.port, {});
    defer sock.destroy()!!;
    
    send_request(sock, &req)!!;
    recieve_response(sock, &res)!!;
    
    return res;
}

fn Response get(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("GET", url, cookies, headers, body); 
}
fn Response options(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("OPTIONS", url, cookies, headers, body); 
}
fn Response head(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("HEAD", url, cookies, headers, body); 
}
fn Response post(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("POST", url, cookies, headers, body); 
}
fn Response put(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("PUT", url, cookies, headers, body); 
}
fn Response patch(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("PATCH", url, cookies, headers, body); 
}
fn Response delete(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("DELETE", url, cookies, headers, body); 
}