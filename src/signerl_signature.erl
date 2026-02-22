-module(signerl_signature).

-export([add_signature_element/2, extract_signature/1]).

-spec add_signature_element(Message, SignatureBytes) -> SignedMessage when
    Message :: signerl_xml:simplified_xml(),
    SignatureBytes :: binary(),
    SignedMessage :: signerl_xml:simplified_xml().
add_signature_element(Message, SignatureBytes) ->
    SignatureElement = construct_signature(SignatureBytes),
    signerl_xml:add_new_element(SignatureElement, Message).

-spec extract_signature(Message) -> Result when
    Message :: signerl_xml:simplified_xml(),
    Result :: {ok, binary(), signerl_xml:simplified_xml()} | {error, invalid_signature}.
extract_signature({Tag, Attrs, Content}) ->
    {SignatureElements, UnsignedContent} = lists:partition(fun is_signature_element/1, Content),
    case SignatureElements of
        [SignatureElement] ->
            case signature_value(SignatureElement) of
                {ok, SignatureBytes} ->
                    {ok, SignatureBytes, {Tag, Attrs, UnsignedContent}};
                {error, invalid_signature} ->
                    {error, invalid_signature}
            end;
        _ ->
            {error, invalid_signature}
    end.

-spec construct_signature(SignatureBytes) -> signerl_xml:simplified_xml() when
    SignatureBytes :: binary().
construct_signature(SignatureBytes) ->
    SignatureValue = base64:encode(SignatureBytes),
    {'ds:Signature', [], [{'ds:SignatureValue', [], [binary_to_list(SignatureValue)]}]}.

is_signature_element({'ds:Signature', _, _}) ->
    true;
is_signature_element(_) ->
    false.

signature_value({'ds:Signature', _, SignatureContent}) ->
    case [Element || Element <- SignatureContent, is_signature_value_element(Element)] of
        [SignatureValueElement] ->
            decode_signature_value(SignatureValueElement);
        _ ->
            {error, invalid_signature}
    end.

is_signature_value_element({'ds:SignatureValue', _, _}) ->
    true;
is_signature_value_element(_) ->
    false.

decode_signature_value({'ds:SignatureValue', _, [SignatureValue]}) when is_list(SignatureValue) ->
    decode_signature_value_binary(list_to_binary(SignatureValue));
decode_signature_value({'ds:SignatureValue', _, [SignatureValue]}) when is_binary(SignatureValue) ->
    decode_signature_value_binary(SignatureValue);
decode_signature_value(_) ->
    {error, invalid_signature}.

decode_signature_value_binary(<<>>) ->
    {error, invalid_signature};
decode_signature_value_binary(SignatureValue) ->
    try
        {ok, base64:decode(SignatureValue)}
    catch
        _:_ ->
            {error, invalid_signature}
    end.
