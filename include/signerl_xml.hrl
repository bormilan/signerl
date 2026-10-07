-define(XML_PROLOG_EXTRACT_RE, <<"^<\\?xml[^>]*\\?>">>).

-define(XML_PROLOG_VALID_RE, <<
    "^<\\?xml\\s+version\\s*=\\s*(['\"])(1\\.[01])\\1"
    "(?:\\s+encoding\\s*=\\s*(['\"])[Uu][Tt][Ff]-8\\3)?"
    "(?:\\s+standalone\\s*=\\s*(['\"])(yes|no)\\4)?\\s*\\?>$"
>>).

-define(XML_ENCODING_EXTRACT_RE, <<
    "^(?:\\xEF\\xBB\\xBF)?<\\?xml\\s+[^?]*\\sencoding\\s*=\\s*(['\"])([^'\"]+)\\1"
>>).

% Custom entities are unsupported; never recurse into replacement text.
-define(XML_ENTITY_RECURSE_LIMIT, 0).
