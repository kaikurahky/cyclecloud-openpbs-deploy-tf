# Azure CycleCloud + OpenPBS Terraform Lab

[Slurm 版](https://github.com/kaikurahky/cyclecloud-deploy-tf)と同様に Azure 基盤を Terraform で展開し、[Azure/cyclecloud-pbspro](https://github.com/Azure/cyclecloud-pbspro) の公式プロジェクトから OpenPBS クラスタを作る検証用リポジトリです。

**最初に [構築ガイド](docs/deployment-guide.md) を参照してください。** 前提条件、事前準備、CycleCloud 初期設定、OpenPBS 導入、ジョブ実行、停止・削除まで順番に説明しています。

## 構成と自動化範囲

| 段階 | 内容 | 実行方法 |
| --- | --- | --- |
| Azure 基盤 | RG、管理/Locker 用 ID と RBAC、VNet、管理/クラスタ用 Subnet・NSG、NAT Gateway | Terraform |
| ストレージ | 非公開 Blob Locker、Private Endpoint、Private DNS、任意の ANF Flexible/NFSv4.1 | Terraform |
| CycleCloud | Marketplace VM、固定 Private IP、SSH 公開鍵認証、イメージ内データディスク | Terraform |
| 初期設定 | Web 管理者、Azure 資格情報、Locker、CLI 認証 | 手動 |
| OpenPBS | 公式プロジェクト取得、SHA-256 照合、Locker 登録、テンプレート登録 | スクリプト |
| クラスタ | Terraform 出力から JSON 生成、クラスタ定義作成 | スクリプト、または UI |
| 起動前確認 | Cloud-init、共有ストレージ、アクセス、コスト・上限 | 手動 |
| 動作確認 | 単体ジョブ、2 ノード/4 ランク MPI、自動スケール | PBS サンプル |

VM に Public IP は付けません。Bastion、VPN、ExpressRoute、踏み台などの到達経路は別途用意してください。NAT Gateway はアウトバウンド用で、管理アクセス用ではありません。

## クイックスタート

Linux/WSL、Bash、Azure CLI、Terraform 1.14 以上、Git、curl、jq、SSH が必要です。Private リポジトリはアクセス権のある GitHub アカウントで取得してください。

```bash
gh repo clone kaikurahky/cyclecloud-openpbs-deploy-tf
cd cyclecloud-openpbs-deploy-tf
cp config/cyclecloud.env.example config/cyclecloud.env
cp config/openpbs.env.example config/openpbs.env
```

2 つの設定ファイルを編集し、[事前準備](docs/deployment-guide.md#2-事前準備)を完了させてから実行します。

```bash
az login
bash scripts/plan.sh
bash scripts/deploy.sh
terraform -chdir=infra output
```

`deploy.sh` は plan を表示して確認を求めます。CycleCloud の初期設定やクラスタ起動までは行いません。

CycleCloud 初期設定後、サーバ上で:

```bash
cyclecloud initialize
cyclecloud locker list
bash scripts/prepare-openpbs.sh YOUR_LOCKER_NAME
bash scripts/create-cluster.sh openpbs01 work/openpbs-parameters.json
```

パラメータの生成・転送、Cloud-init 設定、起動操作は [構築ガイド](docs/deployment-guide.md) の順序に従ってください。設定ファイルは Bash として読み込むため、信頼できるものだけ使用してください。

## バージョン

| 対象 | 固定値・既定値 |
| --- | --- |
| AzureRM Provider | 5.6.0、lock ファイル同梱 |
| Terraform | 1.14 以上、2.0 未満 |
| cyclecloud-pbspro | 2.0.26 / commit `2e42f3978ccc0c68f4d20b6b97858ce32b5f38d9` |
| OpenPBS 本体 | 22.05.11-0、EL8/x86_64 |
| PBS ノード OS | AlmaLinux HPC 8.10 Gen2 |
| CycleCloud 管理 VM | CycleCloud 8 Gen2 Marketplace イメージ |

`2.0.26` は CycleCloud 統合プロジェクトのバージョンです。OpenPBS 本体の `22.05.11-0` とは異なります。イメージの `latest` は更新されるため、再現性が必要な場合はリージョンで利用可能な具体的バージョンを指定してください。AlmaLinux 9、Ubuntu、ARM64 への置き換えはこの手順の対象外です。

## 検証

```bash
bash scripts/validate.sh
bash scripts/prepare-openpbs.sh --download-only
bash tests/scripts.sh
```

`validate.sh` は ShellCheck、Bash 構文検査、パラメータ回帰テスト、Terraform validate、mock Provider の plan テストを実行します。Azure 認証や有料リソースの作成は不要です。Terraform Provider と上流プロジェクトの取得にはインターネット接続が必要です。

2026-09-18 時点でローカル検証および公式リリース 13 ファイルのダウンロード・ハッシュ照合を実施しました。**Azure 実環境への apply、CycleCloud への登録、PBS/MPI 実行は未検証**です。実環境での受入基準は [構築ガイド](docs/deployment-guide.md#10-受入確認チェックリスト) に記載しています。

## 注意事項

- 検証環境向けです。管理 ID にサブスクリプションの Contributor を付与します。実行者にはリソース作成と RBAC 割り当ての権限が必要です。
- 計算ノード用 ID は Locker の Storage Blob Data Reader のみです。管理 ID を計算ノードに設定しないでください。
- NSG は既定の VNet 内通信を許可します。CIDR 入力だけで VNet 内の厳密な分離が実現されるわけではありません。
- ANF、NAT Gateway、ディスクなどはジョブがなくても課金されます。公式テンプレートの `/sched` ディスクは 1 TiB です。
- Terraform は CycleCloud が作ったクラスタを管理しません。削除前にクラスタを終了し、共有データを退避してください。
- state、plan、実設定、鍵、ダウンロード物は Git に含めません。state は機密情報として安全に保管してください。
- 本リポジトリは Microsoft 公式製品ではありません。上流コードと配布物のライセンスは [出典](docs/sources.md) を参照してください。

## ファイル

- [config/cyclecloud.env.example](config/cyclecloud.env.example): Azure 基盤の入力例
- [config/openpbs.env.example](config/openpbs.env.example): OpenPBS クラスタの入力例
- [infra](infra): Terraform と mock テスト
- [scripts](scripts): 展開、検証、プロジェクト登録、クラスタ作成
- [examples](examples): PBS/MPI サンプル
- [docs/deployment-guide.md](docs/deployment-guide.md): 記事形式の構築手順
- [docs/sources.md](docs/sources.md): 出典・バージョン更新方針