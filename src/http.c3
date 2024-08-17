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

////


//// Request methods

fn Request Request.header(&self, String key, String value) 
{
    self.headers.push({.key=key, .value=value});
    return *self;
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

fn Response recieve_response(TcpSocket socket)
{
    Response r;
    ByteWriter writer; 
    writer = *writer.temp_init();

    char[4096] buffer;
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
            r.protocol = status_line[0];
            r.status_code = status_line[1].to_uint()!!;
            r.status_message = status_line[2];
        }   
        else
        {
            // parse headers
            String[] kv = line.trim().split(":", 2);
            r.headers.push({.key=kv[0], .value=kv[1]});
            
            String lower_key = kv[0].temp_ascii_to_lower();
            // if content-length header - save value
            
            if ("content-length" == lower_key)
            {
                content_length = kv[1].to_uint()!!;
            }
            else if("set-cookie" == lower_key)
            {
                Cookie cookie = parse_set_cookie(kv[1]); 
                r.jar.set_cookie(cookie);
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
        r.body = body;
        return r;
    }

    // Read the remaining data from the socket
    while(try bytes = socket.read(buffer[:buffer.len]) && bytes > 0) 
    {
        writer.write(buffer[:buffer.len])!!;
        remaining -= (uint) bytes;
        //io::printfn("%d", remaining);
        buffer = {};
        if( remaining < 0 )
        {
            r.body = body;
            return r;
        }   
    }
    return r;
}


fn Response Request.send(&self) 
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

    foreach(header: self.headers) {
        w.write(header.key.concat(": ").concat(header.value).concat("\r\n"))!!;
    }
    w.write("\r\n")!!;

    usz bytes_written = sock.write(w.str_view())!!;

    res = recieve_response(sock)!!;
    
    //w.destroy()!!;
    //w.temp_init();
    //char[4096] buffer;
    //while(try usz bytes_received = sock.read(buffer[:buffer.len]) && bytes_received > 0) {
    //    io::printfn("\nReceived: %d bytes", bytes_received);
    //    w.write(buffer[:bytes_received])!!;
    //    if(((String)buffer[:bytes_received]).contains("\r\n\r\n")) {
    //        break;
    //    }
    //}
    //io::printfn("revieved: \n");
    //io::printfn(w.str_view());
//
    //if(w.str_view().contains("\r\n\r\n")){
//
    //}




    //String[] data = w.str_view().split("\r\n\r\n");
    //res.body = data[1];
//
    //String[] message = data[0].split("\r\n");
    //
    //
    //    String[] response_status = message[0].split(" ");
    //    res.protocol = response_status[0];
    //    res.code = response_status[1].to_uint()!!;
    //    res.status = response_status[2];
//
    //    for(i in 1..<message.len) {
    //        String[] header = message[i].split(":");
    //        String key = header[0].strip(" ");
    //        String value = header[1].strip(" ");
    //        res.headers.push({.key=key, .value=value});
//
    //        if (key.to_lower() == "set-cookie") {
    //            String[] cookie_data = value.split(";");
    //            String[] name_value = cookie_data[0].strip(" ").split("=");
    //            Cookie cookie = {
    //                .name = name_value[0],
    //                .value = name_value[1]
    //            };
//
    //            for(j in 1..<cookie_data.len) {
    //                String[] attr = cookie_data[j].strip(" ").split("=");
    //                if (attr[0] == "Domain") {
    //                    cookie.domain = attr[1];
    //                } else if (attr[0] == "Path") {
    //                    cookie.path = attr[1];
    //                } else if (attr[0] == "Expires") {
    //                    cookie.expires = attr[1];
    //                } else if (attr[0] == "Secure") {
    //                    cookie.secure = true;
    //                } else if (attr[0] == "HttpOnly") {
    //                    cookie.http_only = true;
    //                }
    //            }
//
    //            self.cookies.add(cookie);
    //        }
    //    }
    //}

    return res;
}

fn Request request(String method, String url) 
{
    Url req_url = url::parse(url)!!;
    list::List(<Header>) headers;
    headers.new_init();

    headers.push({.key="Connection", .value="keep-alive"});
    headers.push({.key="Host", .value=req_url.host});

    Request req = {
        .protocol="HTTP/1.1",
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