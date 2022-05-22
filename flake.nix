{
  description = "Build support for fetching from the Internet Archive.";
  inputs = {
    nixpkgs.url = github:nixos/nixpkgs/nixpkgs-unstable;
  };
  outputs = inputs @ {
    self,
    nixpkgs,
  }:
    with builtins; let
      std = nixpkgs.lib;
    in {
      overlays.default = final: prev: let
        fetchIAMetadata = base @ {
          collection,
          hash ? null,
          __impure ? false,
          ...
        }:
          assert (hash == null) -> __impure;
          assert __impure -> (hash == null);
            final.stdenvNoCC.mkDerivation ({
                name = "${collection}.json";
                inherit __impure;
                nativeBuildInputs = with final; [python310Packages.internetarchive];
                builder = final.writeText "iameta.sh" ''
                  source $stdenv/setup
                  echo "Retrieving metadata for ${collection} from Internet Archive; outputting to $out"
                  ia metadata ${collection} > $out
                '';
              }
              // (
                std.optionalAttrs (base.hash != null)
                {
                  outputHash = base.hash;
                  outputHashAlgo = null;
                  outputHashMode = "flat";
                  __contentAddressed = true;
                }
              ));
        fetchIA = base @ {
          collection,
          file,
          outputHashMode ? "flat",
          downloadToTemp ? false,
          postFetch ? "",
          nativeBuildInputs ? [],
          ...
        }: let
          hashAlgo =
            if file ? sha512
            then "sha512"
            else if file ? sha256
            then "sha256"
            else if file ? sha1
            then "sha1"
            else if file ? md5
            then "md5"
            else throw "fetchIA could not find hash for file: ${collection}::${file.name}";
          hashVal = file.sha512 or file.sha256 or file.sha1 or file.md5;
        in
          final.stdenvNoCC.mkDerivation (base
            // {
              name = file.name;
              file = file.name;
              passthru = {
                metadata = file;
              };
              outputHashAlgo =
                if file ? hash
                then null
                else hashAlgo;
              outputHash = file.hash or hashVal;
              nativeBuildInputs = nativeBuildInputs ++ (with final; [python310Packages.internetarchive]);
              builder = ./fetchia.sh;
            });
        mkImpure' = __impure: drv: drv // {inherit __impure;};
        mkImpure = drv: mkImpure' true drv;
      in {
        inherit fetchIA;
        inherit fetchIAMetadata;
        mkIACollection = base @ {
          collection,
          override ? {},
          meta ? {},
          __impure ? false,
          hash ? null,
          ...
        }:
          final.stdenvNoCC.mkDerivation ((removeAttrs base ["override" "hash"])
          // {

          } // rec {
              name = base.pname or collection;
              src = final.fetchIAMetadata {inherit collection __impure hash;};
              meta =
                base.meta
                // {
                  inherit (src) description;
                  maintainers = [src.uploader];
                  homepage = "https://archive.org/details/${name}";
                };
              passthru =
                std.foldl
                (acc: file:
                  acc
                  // (
                    let
                      pname = file.name; # std.last (match "" file.name);
                    in {
                      "${file.name}" = final.fetchIA ({
                          inherit collection file;
                        }
                        // override);
                    }
                  ))
                {}
                (fromJSON (readFile src)).files;
            });
      };
    };
}
