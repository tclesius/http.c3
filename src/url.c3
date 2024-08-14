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
}

fault UrlError
{
    TEST,
}


fn String isubstring(String self, String start_pattern, String end_pattern)
{
    usz! start = self.index_of(start_pattern);
    if (catch start) return "";
    
    usz search_start = start + start_pattern.len;
    usz! end = self[search_start..].index_of(end_pattern);
    if (catch end) return "";
    
    return self[start + start_pattern.len : search_start + end];
}

fn Url! parse(String url)
{
    Url result;
    io::printfn(isubstring(url, "://", ":"));
    io::printfn(isubstring(url, "://", ":"));
    return result;
}