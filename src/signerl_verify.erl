-module(signerl_verify).

-export([extract_signature/1]).

-spec extract_signature(Message) -> Result when
    Message :: {atom(), [{atom(), string() | number()}], [any()]},
    Result ::
        {ok, binary(), {atom(), [{atom(), string() | number()}], [any()]}, map()}
        | {error, invalid_signature}.
extract_signature({Tag, Attrs, Content}) ->
    {SignatureElements, UnsignedContent} = lists:partition(fun is_signature_element/1, Content),
    case SignatureElements of
        [SignatureElement] ->
            case {signature_value(SignatureElement), signed_properties(SignatureElement)} of
                {{ok, SignatureBytes}, {ok, SignedProperties}} ->
                    {ok, SignatureBytes, {Tag, Attrs, UnsignedContent}, SignedProperties};
                {{error, invalid_signature}, _} ->
                    {error, invalid_signature};
                {_, error} ->
                    {error, invalid_signature}
            end;
        _ ->
            {error, invalid_signature}
    end.

is_signature_element({'ds:Signature', _, _}) ->
    true;
is_signature_element(_) ->
    false.

signature_value({'ds:Signature', _, SignatureContent}) ->
    SignatureElement = {'ds:Signature', [], SignatureContent},
    decode_signature_value(signerl_xml:find_path(['ds:SignatureValue'], SignatureElement)).

signed_properties({'ds:Signature', _, SignatureContent}) ->
    signerl_signed_properties:extract({'ds:Signature', [], SignatureContent}).

decode_signature_value({ok, {'ds:SignatureValue', _, [SignatureValue]}}) ->
    try
        decode_signature_value_binary(iolist_to_binary(SignatureValue))
    catch
        _:_ ->
            {error, invalid_signature}
    end;
decode_signature_value({ok, {'ds:SignatureValue', _, _}}) ->
    {error, invalid_signature};
decode_signature_value(error) ->
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
