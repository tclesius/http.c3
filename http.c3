module http;
import cookie;
import url;
import std::collections::map;
import std::collections::object;
import std::collections::list;
import std::encoding::json;
import std::net::tcp;
import std::io;
import std::time::datetime;


// @TODO: Streamiterator error if Iterator exhaused
struct Header 
{
    String key;
    String value;
}

struct Param
{
    String key;
    String value;
}

struct Response 
{
    ContentIterator content_iter;
    CookieJar jar;
    bool stream; 
    bool stream_end; // TODO: maybe add stream_end to know if stream_iterator now only iterates over loaded body
    String protocol;
    uint status_code;
    String status_message;
    // DString body;
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



struct ContentIterator 
{
    TcpSocket* socket; // i dont like that this is in here
    bool chunked; // is Transfer-Encoding: chunked
    bool chunked_end; // reached end of Transfer-Encoding: chunked
    uint content_length;
    int content_remaining;
    DString buffer;
    DString body;
}
 
fn String! ContentIterator.next(&self, uint chunk_size = 1024)
{
    if ((self.chunked && self.chunked_end) || (!self.chunked && self.content_remaining <= 0)){
        return IteratorResult.NO_MORE_ELEMENT?;
    }
    
    if(self.chunked)
    {
        // Decode chunked transfer encoding
        while(self.buffer.len() < chunk_size)
        {
            DString hex_len;
            hex_len.temp_init();

            // Read chunk size line (in hex) until \r\n
            while(try byte = self.socket.read_byte()) 
            {
                hex_len.append_char(byte);
                // read data from the socket until "\r\n" marker is encountered.
                if (hex_len.str_view().ends_with("\r\n")){    
                    break; 
                }
            }
            // remove \r\n
            hex_len.chop(hex_len.len() - 2);
            
            // Convert the hex length to a uint
            uint chunk_len = hex_len.str_view().to_uint(base : 16)!!;
            
            if (chunk_len == 0) {
                // Final chunk (size 0) indicates the end of the stream
                self.chunked_end = true;
                break;
            }

            
            // Read the actual chunk data
            char[] chunk = mem::new_array(char, chunk_len);
            usz bytes_read = self.socket.read(chunk[:chunk_len])!!;
            self.buffer.append_chars((String) chunk[:bytes_read]);
            free(chunk);
            
            // Read and discard the trailing \r\n after each chunk
            char[2] crlf;
            self.socket.read(crlf[:2])!!;
        }
    } 
    else 
    {
        // Non-chunked mode: read up to content-length
        while(self.buffer.len() < chunk_size && self.content_remaining > 0)
        {
            char[] chunk = mem::new_array(char, min(chunk_size, self.content_remaining));
            usz bytes_read = self.socket.read(chunk[:chunk.len])!!;
            self.buffer.append_chars((String) chunk[:chunk.len]);
            self.content_remaining -= (uint) bytes_read; 
            free(chunk);
            if (bytes_read == 0) {
                break;  // EOF
            }
        }
    }

    String result = self.buffer.str_view()[0:min(chunk_size, self.buffer.len())];
    self.body.append(result);
    if (!self.chunked_end)
    {
        self.buffer.delete_range(0, result.len - 1);
    }
    else
    {
        // some cleanup
        self.socket.close()!!;
        self.buffer.clear();
    }
    return result;
}

//// Response methods

fn void Response.recieve(&self, TcpSocket* socket)
{
    DString header;
    header.temp_init();
    DString body;
    body.temp_init();
    // read header from the socket
    while(try byte = socket.read_byte()) 
    {
        header.append_char(byte);
        // Read data from the socket until "\r\n\r\n" marker is encountered.
        if (header.str_view().ends_with("\r\n\r\n")){    
            break; 
        }
    }
    
    header.chop(header.len() - 4); // remove last \r\n\r\n
    uint content_length = 0;
    bool chunked = false;
    
    // parse status line and headers
    foreach(ix, line: header.str_view().split("\r\n"))
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

    // initialize the stream iterator
    // @TODO make a new constructor for stream_iter
    self.content_iter = {
        .socket=socket,
        .chunked=chunked,
        .content_length=content_length,
        .content_remaining=content_length,
    };

    if (!self.stream)
    {
        while(try chunk = self.content_iter.next()) { }
    }
}

fn void Request.send(&self, TcpSocket* socket)
{
    DString data;
    data.temp_init();
    // write request line and url encode the query params
    data.appendf("%s %s%s %s\r\n", self.method, self.url.path, self.url.query, self.protocol);
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

fn Response request(String method, String url, Param[] params = {}, Cookie[] cookies = {}, Header[] headers = {}, String body = "", bool stream = false) 
{
    Url req_url = url::parse(url)!!;

    if(params.len > 0)
    {
        DString query;
        
        query.append(req_url.query); // TODO: these query params need to be split up and quoted 
        
        foreach(ix, param: params){
            if (ix == 0 && req_url.query.len > 0)
            {
                query.append('&');
            }  
            if (ix == 0 && req_url.query.len == 0)
            {
                query.append('?');
            }  
            query.appendf("%s=%s", url::quote(param.key), url::quote(param.value));
            if (ix < params.len)
            {
                query.append('&');
            }
        }
        req_url.query = query.str_view();
    }

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

    req.send(&sock)!!;
    res.recieve(&sock)!!;
    
    return res;
}

fn Object*! Response.json(&self) 
{
    return json::parse_string(self.text());
}

fn String Response.text(&self) 
{
    return self.content_iter.body.str_view();
}

fn Response get(String url, Param[] params = {}, Cookie[] cookies = {}, Header[] headers = {}, String body = "", bool stream = false) 
{ 
    return request("GET", url=url, params : params, cookies : cookies, headers : headers, body : body, stream : stream); 
}
fn Response options(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("OPTIONS", url=url, cookies : cookies, headers : headers, body : body);
}
fn Response head(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("HEAD", url=url, cookies : cookies, headers : headers, body : body); 
}
fn Response post(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("POST", url=url, cookies : cookies, headers : headers, body : body); 
}
fn Response put(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("PUT", url=url, cookies : cookies, headers : headers, body : body); 
}
fn Response patch(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("PATCH", url=url, cookies : cookies, headers : headers, body : body); 
}
fn Response delete(String url, Cookie[] cookies = {}, Header[] headers = {}, String body = "") 
{ 
    return request("DELETE", url : url, cookies : cookies, headers : headers, body : body); 
}
