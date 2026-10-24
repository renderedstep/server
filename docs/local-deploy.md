# The private install

One machine runs the app for its owner's devices on a tailnet, nobody else. It
listens on `127.0.0.1` only; `tailscale serve` gives it an https address on the
tailnet and is the one way in. This leaves any public deployment (Kamal,
`config/deploy.yml`) unchanged.

| Piece | Where |
| --- | --- |
| Checkout | `~/.local/share/text-adventure-web/app` |
| Settings | `~/.local/share/text-adventure-web/deploy.env` (from `deploy/local/deploy.env.example`) |
| Secrets | `~/.local/share/text-adventure-web/secrets.env`, mode 600 |
| Web | `bin/start` on `127.0.0.1:3200`, `deploy/local/text-adventure-web.service` |
| Line reader | `bin/pointer-classifier` on `127.0.0.1:3201`, `deploy/local/text-adventure-web-reader.service` |
| Address | `https://<machine>.<tailnet>.ts.net:8445` |

## Install

```sh
root=~/.local/share/text-adventure-web
git clone <repo> "$root/app"
cp "$root/app/deploy/local/deploy.env.example" "$root/deploy.env"   # edit paths and RAILS_ALLOWED_HOSTS
install -m 600 /dev/null "$root/secrets.env"                        # SECRET_KEY_BASE, model key
(cd "$root/app" && bundle install && bin/rails engine:build && bin/rails assets:precompile)

cp "$root/app/deploy/local/"*.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now text-adventure-web-reader text-adventure-web
loginctl enable-linger "$USER"

tailscale serve --bg --https=8445 http://127.0.0.1:3200
```

`RAILS_ALLOWED_HOSTS` must name the tailnet host, or Rails refuses every request
that arrives through it. `/up` is exempt, so
`curl http://127.0.0.1:3200/up` checks the app from the machine itself.

## Update

```sh
(cd ~/.local/share/text-adventure-web/app && git pull && bin/update)
systemctl --user restart text-adventure-web
```

## Roll back

To go back to a previous version, check out the earlier commit in the checkout
and restart the unit. To take the app off the tailnet entirely:

```sh
tailscale serve --https=8445 off
systemctl --user disable --now text-adventure-web text-adventure-web-reader
```

Unsetting `RAILS_ALLOWED_HOSTS` turns host checking off again, should the
address change before the setting does.
