module urln;
import std::io;

struct Url
{
    String scheme;
    String host;
    uint port;
    String path;
    String query;
    String fragment;
}

fault UrlError
{
    MISSING_SCHEME,
    UNKOWN_SCHEME,
    MISSING_HOST_PORT,
    MISSING_PORT,
    MALFORMED
}

fn uint! default_port(String scheme)
{
    switch (scheme)
    {
        case "http": return 80;
        case "https": return 443;
        default: return UrlError.MISSING_PORT?;
    }
}

fn Url! parse(String url)
{
    Url result;
    
    // parse scheme
    usz! scheme_end = url.index_of("://");
    if (catch scheme_end) 
    {
        return UrlError.MISSING_SCHEME?;
    }    
    result.scheme = url[:scheme_end];

    // parse host and port
    usz host_start = scheme_end + 3;
    usz! host_end = url[host_start..].index_of("/") - 1; // append "/" to end for best efford
    if (catch host_end)
    {
        
    }
    String host_port = url[host_start..host_start + host_end!!];
    usz! port_separator = host_port.index_of(":");
    if (catch port_separator)
    {
        result.port = default_port(result.scheme)!!;
    } 
    else 
    {
        result.port = host_port[port_separator + 1..].to_uint()!!;
    }
    
    result.host = host_port[:port_separator!!];
    
    //parse path
    usz path_start = 1 + host_start + host_end!!;
    usz! path_end = url[path_start..].index_of("?") - 1;
    // TODO: catch
    result.path = url[path_start..path_start + path_end!!];;

    //parse query
    usz query_start = 1 + path_start + path_end!!;
    usz! query_end = url[query_start..].index_of("#") - 1;
    // TODO: catch
    result.query = url[query_start..query_start + query_end!!];;
    
    // parse fragment
    usz! fragment_start = url[query_start + query_end!!..].index_of("#");
    if (catch fragment_start)
    {
        result.fragment = "";
    }
    else
    {
        result.fragment = url[query_start + query_end!! + fragment_start + 1..];
    }
    return result;
}