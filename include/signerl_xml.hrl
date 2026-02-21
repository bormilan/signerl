-define(XML_PROLOG_EXTRACT_RE, <<"^<\\?xml[^>]*\\?>">>).

-define(XML_PROLOG_VALID_RE, <<
    "^<\\?xml\\s+version\\s*=\\s*(['\"])(1\\.[01])\\1"
    "(?:\\s+encoding\\s*=\\s*(['\"])[A-Za-z][A-Za-z0-9._-]*\\3)?"
    "(?:\\s+standalone\\s*=\\s*(['\"])(yes|no)\\4)?\\s*\\?>$"
>>).
