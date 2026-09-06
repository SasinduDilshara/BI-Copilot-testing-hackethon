// SMB share connection configuration. Populated from Config.toml at runtime; never hardcode secrets.
configurable string smbHost = ?;
configurable int smbPort = ?;
configurable string smbShareName = ?;
configurable string smbUsername = ?;
configurable string smbPassword = ?;
configurable string smbDomain = ?;
