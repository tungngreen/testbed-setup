### Vaults
All vaults are not included for obvious security reasons.
But the entries should look like this

For server vault:
```
server_creds:
  bulbasaur:
    user: user_name
    password: password
    become_pass: password
    ip: zzx.xxx.zzz.xxx
```

For Jetson devices vault:
```
jetsons_creds:
  bulbasaur:
    user: user_name
    password: password
    become_pass: password
    ip: zzx.xxx.zzz.xxx
```