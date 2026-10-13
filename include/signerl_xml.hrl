-define(XML_NAMESPACE_URI, <<"http://www.w3.org/XML/1998/namespace">>).
-define(XMLNS_NAMESPACE_URI, <<"http://www.w3.org/2000/xmlns/">>).

% XML 1.0 (fifth edition) NameStartChar, excluding the namespace separator.
-define(XML_NCNAME_START_RE,
    "A-Za-z_\\x{C0}-\\x{D6}\\x{D8}-\\x{F6}\\x{F8}-\\x{2FF}"
    "\\x{370}-\\x{37D}\\x{37F}-\\x{1FFF}\\x{200C}-\\x{200D}"
    "\\x{2070}-\\x{218F}\\x{2C00}-\\x{2FEF}\\x{3001}-\\x{D7FF}"
    "\\x{F900}-\\x{FDCF}\\x{FDF0}-\\x{FFFD}\\x{10000}-\\x{EFFFF}"
).
-define(XML_NCNAME_RE, <<
    "^[",
    ?XML_NCNAME_START_RE,
    "][",
    ?XML_NCNAME_START_RE,
    "0-9.\\x{2D}\\x{B7}\\x{300}-\\x{36F}\\x{203F}-\\x{2040}]*\\z"
>>).

% Check only start-tag attributes. Skip comments/CDATA and consume quoted values
% so namespace-like literal text cannot trigger this lost-SAX-information guard.
-define(XML_EMPTY_NAMESPACE_PREFIX_RE, <<
    "<!--[\\s\\S]*?-->(*SKIP)(*F)|<!\\[CDATA\\[[\\s\\S]*?\\]\\]>(*SKIP)(*F)|"
    "<[^!?/\\s<>]+(?:[\\x20\\t\\r\\n]+(?!xmlns:[\\x20\\t\\r\\n]*=)"
    "[^\\x20\\t\\r\\n=<>]+[\\x20\\t\\r\\n]*=[\\x20\\t\\r\\n]*"
    "(?:\"[^\"]*\"|'[^']*'))*[\\x20\\t\\r\\n]+xmlns:[\\x20\\t\\r\\n]*="
>>).

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
