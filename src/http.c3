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
    ContentIterator content_iter;
    CookieJar jar;
    // if stream = false: (default) load head and body
    // if stream = true: load only head rest gets loaded with iterator
    bool stream; // do i want to only load the head and load the rest lazy with iterator
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

struct CookieJar 
{
    HashMap(<String, Cookie>) cookies;
}


struct ContentIterator 
{
    TcpSocket* socket;
    bool chunked; // is the encoding from server chunked
    // bool stream; // load data lazily on every next call or not
    int remaining; // if not chunked this is content-length - read if chunked its the next chunksize
    bool init; // flag if it has run 
}

fn bool ContentIterator.has_next(&self)
{
    return (!self.init && self.chunked) || self.remaining > 0;
}

fn char[] ContentIterator.next(&self)
{
    char[1024] buffer;
    //if not chunk encoded then read only one 1024 byte chunk
    if(!self.chunked)
    {
        if (try bytes = self.socket.read(buffer[:buffer.len]) && bytes > 0)
        {
            self.remaining -= (uint) bytes;
        }
    }

    return buffer[:buffer.len];
}


//// Response methods

fn void Response.recieve(&self, TcpSocket* socket)
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
    bool chunked = false;
    
    foreach(ix, line: header.split("\r\n"))
    {
        if(ix == 0)
        {
            // parse status line
            String[] status_line = line.trim().split(" ", 3);
            self.protocol = status_line[0];
            self.status_code = status_line[1].to_uint()!!;
            self.status_message = status_line[2];
        }   
        else
        {
            // parse headers
            String[] kv = line.trim().split(":", 2);
            self.headers.push({.key=kv[0], .value=kv[1]});
            
            String lower_key = kv[0].temp_ascii_to_lower();
            
            // if content-length header - save value
            if ("content-length" == lower_key)
            {
                content_length = kv[1].to_uint()!!;
            }
            else if("set-cookie" == lower_key)
            {
                Cookie cookie;
                cookie.parse(kv[1]); // TODO: domain and path has default if missing!
                self.jar.set_cookie(cookie);
            }
            else if ("transfer-encoding" == lower_key)
            {
                // set flag if content is chunk encoded
                chunked = "chunked" == kv[1].trim().temp_ascii_to_lower();
            }
        }
    }
    // calculate the remaining data to be send (used if not chunked)
    int remaining = content_length - body.len;
    // initialize the content iterator
    self.content_iter = {
        .socket=socket,
        .chunked=chunked,
        .remaining=chunked ? remaining : 0
    };

    if (!self.stream)
    {
        while(self.content_iter.has_next())
        {
            writer.write(self.content_iter.next())!!;
        }
        
        self.body = writer.str_view()[header.len:header.len + content_length];
        return;
    }
}

fn void Request.send(&self, TcpSocket* socket)
{
    DString data;
    data.temp_init();
    // write request line
    data.appendf("%s %s %s\r\n", self.method, self.url.path, self.protocol);
    // write request headers
    foreach(header: self.headers)
    {
        data.appendf("%s: %s\r\n", header.key, header.value);
    }
    // write content-length if body present
    if(self.body.len > 0)
    {
        data.appendf("Content-Length: %d", self.body.len);
    }
    // write relevant cookie headers
    foreach(ix, cookie: self.jar.cookies.value_tlist())
    {   
        if (cookie.domain == self.url.host && cookie.path == self.url.path) // @TODO domain != host
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
    data.appendf(self.body);
    
    // write all the data to the socket
    int last_pos = 0;
    String buffer = data.str_view();
    while(try bytes = socket.write(buffer[last_pos:buffer.len]) && bytes > 0) 
    {
        last_pos += (uint) bytes;
        if( last_pos >= self.body.len ){ break; }   
    }
}

fn Response request(String method, String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "", bool stream = false) 
{
    Url req_url = url::parse(url)!!;
    Response res = {
        .stream = stream
    };
    List(<Header>) headers_;
    headers_.new_init_with_array(headers);

    headers_.push({"Connection", "keep-alive"});
    headers_.push({"Host", req_url.host});
    headers_.push({"User-Agent", "c3c/http"});
    
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
        .jar=jar,
    };

    TcpSocket! sock = tcp::connect(req.url.host, req.url.port, {});
    defer sock.destroy()!!;
    
    req.send(&sock)!!;
    res.recieve(&sock)!!;
    
    return res;
}

fn Object*! Response.json(&self) 
{
    return json::parse_string(self.body);
}

fn String Response.text(&self) 
{
    return self.body;
}

fn Response get(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "", bool stream = false) 
{ 
    return request("GET", url, cookies, headers, body, stream); 
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

//// Cookie methods
fn String Cookie.to_string(&self)
{
    DString result;
    result.new_init();
    result.appendf(
        "<Cookie %s=%s; Domain=%s; Path=%s; Expires=%s; Max-Age=%s; SameSite=%s; Secure=%b; HttpOnly=%b>",
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

fn void Cookie.parse(&self, String value)
{
    // iterate over every set-cookie attribute 
    foreach(ix, attribute: value.trim().split(";"))
    {
        // parse key value attributes
        if(attribute.contains("="))
        {
            String[] kv = attribute.trim().split("=");
            // the first key value is always the cookie name and cookie value
            if(ix == 0)
            {
                self.name = kv[0];
                self.value = kv[1];
            } 
            else
            {
                switch(attribute.temp_ascii_to_lower())
                {
                    case "domain": self.domain = kv[1];
                    case "path": self.path = kv[1];
                    case "expires": self.expires = kv[1];
                    case "max-age": self.max_age = kv[1];
                    case "same-site": self.same_site = kv[1];
                }
            }
            continue;
        }
        // parse flag attributes
        switch(attribute.temp_ascii_to_lower())
        {
            case "secure": self.secure = true;
            case "httponly": self.http_only = true;
        }
    }
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