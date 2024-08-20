module url;
import std::io;

struct Url
{
    String scheme;
    String host;
    uint port;
    String path;
    String query;
    String fragment;
    String userinfo;
}


fn uint default_port(String scheme)
{
    switch (scheme)
    {
        case "http": return 80;
        case "https": return 443;
        default: return 80; // default throw error ?
    }
}

fn Url! parse(String url)
{
    Url result;
    
    // Extract scheme
    if (try usz scheme_end = url.index_of("://")) 
    {
        // io::printfn("%d %d",scheme_end, url.len);
        result.scheme = url[0..scheme_end-1];
        url = url[scheme_end+3..url.len-1];
    }

    // Extract fragment
    if (try usz fragment_start = url.index_of("#")) 
    {
        result.fragment = url[fragment_start+1..url.len-1];
        url = url[0..fragment_start-1];
    }

    // Extract query
    if (try usz query_start = url.index_of("?")) 
    {
        result.query = url[query_start+1..url.len-1];
        url = url[0..query_start-1];
    }

    // Extract userinfo
    if (try usz userinfo_end = url.index_of("@")) 
    {
        result.userinfo = url[0..userinfo_end-1];
        url = url[userinfo_end+1..url.len-1];
    }

    // Extract host and port
    usz! path_start = url.index_of("/");
    usz host_end = path_start ?? url.len-1;

    if (try usz port_start = url[0..host_end].index_of(":"))
    {
        result.host = url[0..port_start-1];
        if(try uint port = url[port_start+1..host_end-1].to_uint()){
            result.port = port;
        } 
        else 
        {
            // TODO: maybe throw an error or try to unpack to_uint
        }
    } 
    else 
    {
        result.host = url[0..host_end];
        result.port = default_port(result.scheme); // Default port if not specified
    }

    // Extract path
    if (try path_start) 
    {
        result.path = url[path_start..url.len-1];
    } 
    else 
    {
        result.path = "/";
    }

    return result;
}


fn String quote(String data)
{
    DString encoded;
    foreach(c : data)
    {
        if(c.is_alnum() || @ok("-_.~".index_of_char(c)))
        {
            encoded.append(c);
        }
        else
        {
            encoded.appendf("%%%02X", (uint) c);
        }
    }
    return encoded.str_view();
}

fn String unquote(String data)
{
    DString decoded;
    for(int ix = 0; ix < data.len; ix++)
    {
        char c = data[ix];
        if(c == '%' && ix + 2 < data.len)
        {
            decoded.append((char) data[ix+1:2].to_uint(.base=16)!!);
            ix += 2;
        }
        else
        {
            decoded.append(c);
        }
    }
    return decoded.str_view();
}

fn String quote_plus(String data)
{
    DString encoded;
    foreach(c : data)
    {
        if(c.is_alnum() || @ok("-_.~".index_of_char(c)))
        {
            encoded.append(c);
        }
        else if (c == ' ')
        {
            encoded.append('+');
        }
        else
        {
            encoded.appendf("%%%02X", (uint) c);
        }
    }
    return encoded.str_view();
}

fn String unquote_plus(String data)
{
    DString decoded;
    for(int ix = 0; ix < data.len; ix++)
    {
        char c = data[ix];
        if(c == '%' && ix + 2 < data.len)
        {
            decoded.append((char) data[ix+1:2].to_uint(.base=16)!!);
            ix += 2;
        }
        else if (c == '+')
        {
            decoded.append(' ');
        }
        else
        {
            decoded.append(c);
        }
    }
    return decoded.str_view();
}
