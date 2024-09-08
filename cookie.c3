import std::collections::map;

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

// Cookie Jar 
struct CookieJar 
{
    HashMap(<String, Cookie>) cookies;
}

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
///

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