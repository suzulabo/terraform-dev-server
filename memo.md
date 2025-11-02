# VM side

## setup git authentication

```
gh auth login
gh auth setup-git
```

## install nvm

```
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
```

# Local side

## install gcloud

https://docs.cloud.google.com/sdk/docs/install?hl=ja

## setup ssh

https://medium.com/@liu.peng.uppsala/safe-way-to-connect-your-vscode-to-compute-engine-from-google-cloud-platform-using-ssh-4e64c70fbb45

以下のように実行

```
gcloud compute ssh dev-vscode --project suzulabo-playground --zone asia-northeast1-c --tunnel-through-iap --dry-run
```

vscode に貼り付けると`~/.ssh/config`に追加される

```
 Host dev-vscode
    HostName dev-vscode
    User suzulabo_gmail_com
    IdentityFile /Users/kenji/.ssh/google_compute_engine
    CheckHostIP no
    HashKnownHosts no
    HostKeyAlias compute.2418195641589044992
    IdentitiesOnly yes
    StrictHostKeyChecking no
    UserKnownHostsFile /Users/kenji/.ssh/google_compute_known_hosts
    ProxyCommand /Users/kenji/.config/gcloud/virtenv/bin/python3 /Users/kenji/Downloads/google-cloud-sdk/lib/gcloud.py compute start-iap-tunnel 'dev-vscode' '%p' --listen-on-stdin --project suzulabo-playground --zone=asia-northeast1-c --verbosity=warning
    ProxyUseFdpass no
```

- `Host` と `HostName` の値を`dev-vscode`にする
- User の値を設定する
  - これを設定しないと`Permission denied (publickey).`というエラーになる
  - ローカルのユーザー名でログインしようとするため

## Port forwarding

```
ssh -N -L 3000:localhost:3000 -R 8888:localhost:8888 dev-vscode
```

## Portainer

https://docs.portainer.io/start/install-ce/server/docker/linux
