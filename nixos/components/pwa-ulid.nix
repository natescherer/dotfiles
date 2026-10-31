# Derives the stable ULID PWAsForFirefox needs from a string. Hex digits are all
# valid ULID characters, and the leading 0 keeps the value in the ULID range.
{lib}: key: "0" + lib.toUpper (builtins.substring 0 25 (builtins.hashString "sha256" key))
