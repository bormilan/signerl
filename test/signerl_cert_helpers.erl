-module(signerl_cert_helpers).

-export([
    path/1,
    root_ca_key_path/0,
    root_ca_cert_path/0,
    intermediate_ca_key_path/0,
    intermediate_ca_cert_path/0,
    leaf_key_path/0,
    leaf_cert_path/0,
    chain_full_cert_path/0,
    signer_rsa_key_path/0,
    signer_rsa_cert_path/0,
    signer_ecdsa_key_path/0,
    signer_ecdsa_cert_path/0,
    load_private_key/1,
    load_cert/1,
    load_cert_chain/0,
    root_ca_key/0,
    intermediate_ca_key/0,
    leaf_key/0,
    signer_rsa_key/0,
    signer_ecdsa_key/0
]).

path(RelPath) ->
    Candidates = [
        search_upwards_path(RelPath),
        cwd_path(RelPath),
        priv_dir_path(RelPath),
        lib_dir_path(RelPath)
    ],
    pick_existing(Candidates, RelPath).

cwd_path(RelPath) ->
    case file:get_cwd() of
        {ok, Cwd} -> filename:join([Cwd, "priv", "certs", RelPath]);
        _ -> "priv/certs/" ++ RelPath
    end.

search_upwards_path(RelPath) ->
    case file:get_cwd() of
        {ok, Cwd} -> find_upwards(Cwd, RelPath, 5);
        _ -> undefined
    end.

find_upwards(Dir, RelPath, Depth) when Depth >= 0 ->
    CandidateDir = filename:join([Dir, "priv", "certs"]),
    case filelib:is_dir(CandidateDir) of
        true ->
            filename:join([CandidateDir, RelPath]);
        false ->
            Parent = filename:dirname(Dir),
            case Parent =:= Dir of
                true -> undefined;
                false -> find_upwards(Parent, RelPath, Depth - 1)
            end
    end;
find_upwards(_, _, _) ->
    undefined.

priv_dir_path(RelPath) ->
    case code:priv_dir(signerl) of
        {error, _} -> undefined;
        PrivDir -> filename:join([PrivDir, "certs", RelPath])
    end.

lib_dir_path(RelPath) ->
    case code:lib_dir(signerl) of
        {error, _} -> undefined;
        LibDir -> filename:join([LibDir, "priv", "certs", RelPath])
    end.

pick_existing([undefined | Rest], RelPath) ->
    pick_existing(Rest, RelPath);
pick_existing([Path | Rest], RelPath) ->
    case filelib:is_file(Path) of
        true -> Path;
        false -> pick_existing(Rest, RelPath)
    end;
pick_existing([], RelPath) ->
    "priv/certs/" ++ RelPath.

root_ca_key_path() -> path("root_ca.key.pem").
root_ca_cert_path() -> path("root_ca.cert.pem").
intermediate_ca_key_path() -> path("intermediate_ca.key.pem").
intermediate_ca_cert_path() -> path("intermediate_ca.cert.pem").
leaf_key_path() -> path("leaf.key.pem").
leaf_cert_path() -> path("leaf.cert.pem").
chain_full_cert_path() -> path("chain_full.cert.pem").
signer_rsa_key_path() -> path("signer_rsa.key.pem").
signer_rsa_cert_path() -> path("signer_rsa.cert.pem").
signer_ecdsa_key_path() -> path("signer_ecdsa.key.pem").
signer_ecdsa_cert_path() -> path("signer_ecdsa.cert.pem").

load_private_key(Path) ->
    {ok, KeyRaw} = file:read_file(Path),
    [KeyDer] = public_key:pem_decode(KeyRaw),
    public_key:pem_entry_decode(KeyDer).

load_cert(Path) ->
    {ok, CertRaw} = file:read_file(Path),
    [CertDer] = public_key:pem_decode(CertRaw),
    public_key:pem_entry_decode(CertDer).

load_cert_chain() ->
    {ok, CertRaw} = file:read_file(chain_full_cert_path()),
    CertDers = public_key:pem_decode(CertRaw),
    [public_key:pem_entry_decode(CertDer) || CertDer <- CertDers].

root_ca_key() -> load_private_key(root_ca_key_path()).
intermediate_ca_key() -> load_private_key(intermediate_ca_key_path()).
leaf_key() -> load_private_key(leaf_key_path()).
signer_rsa_key() -> load_private_key(signer_rsa_key_path()).
signer_ecdsa_key() -> load_private_key(signer_ecdsa_key_path()).
