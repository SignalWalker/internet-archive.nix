source $stdenv/setup

echo "Retrieving metadata for $collection from internet archive..."
ia --insecure metadata $collection > $out
