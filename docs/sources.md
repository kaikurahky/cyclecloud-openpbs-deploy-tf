# 出典と保守方針

## 参考にした構成

- [Slurm 版の構築記事](https://zenn.dev/kaikurahky/articles/5252f707f38e2f)
- [kaikurahky/cyclecloud-deploy-tf](https://github.com/kaikurahky/cyclecloud-deploy-tf): Azure 基盤の構成、Marketplace イメージ内データディスクを ARM Template で保持する方式を参考にしています。既存の state、個人設定、資格情報は含めていません。

## OpenPBS 統合

- [Azure/cyclecloud-pbspro](https://github.com/Azure/cyclecloud-pbspro)
- [固定ソース 2.0.26](https://github.com/Azure/cyclecloud-pbspro/tree/2e42f3978ccc0c68f4d20b6b97858ce32b5f38d9)
- [公式テンプレート](https://github.com/Azure/cyclecloud-pbspro/blob/2e42f3978ccc0c68f4d20b6b97858ce32b5f38d9/templates/openpbs.txt)
- [公式のビルド・Locker 登録手順](https://github.com/Azure/cyclecloud-pbspro/blob/2e42f3978ccc0c68f4d20b6b97858ce32b5f38d9/BUILDING.md)
- [公式リリース](https://github.com/Azure/cyclecloud-pbspro/releases/tag/2.0.26)
- [上流 MIT ライセンス](https://github.com/Azure/cyclecloud-pbspro/blob/2e42f3978ccc0c68f4d20b6b97858ce32b5f38d9/LICENSE)

上流プロジェクト・RPM・wheel は `work/` にダウンロードし、本リポジトリでは再配布しません。上流の LICENSE を保持します。個々のバイナリや依存物には各ライセンスが適用されます。新規成果物をオープンソースとして再配布する際は、所有者がリポジトリ全体のライセンスを選定してください。

チェックサムは GitHub Releases API の各 asset の `digest` から 2026-09-18 に取得し、実ダウンロードした 13 ファイルで一致を確認しました。これは取得後の変更検出に役立ちますが、第三者の独立した署名検証を代替するものではありません。

## 公式リファレンス

- [CycleCloud の Managed Identity](https://learn.microsoft.com/azure/cyclecloud/how-to/managed-identities?view=cyclecloud-8)
- [CycleCloud CLI](https://learn.microsoft.com/azure/cyclecloud/cli?view=cyclecloud-8)
- [クラスタ作成と標準 UI セクション](https://learn.microsoft.com/azure/cyclecloud/how-to/create-cluster?view=cyclecloud-8)
- [クラスタテンプレート・パラメータ](https://learn.microsoft.com/azure/cyclecloud/how-to/cluster-templates?view=cyclecloud-8)
- [ノード属性](https://learn.microsoft.com/azure/cyclecloud/cluster-references/node-nodearray-reference?view=cyclecloud-8)
- [AzureRM 5.6.0 ARM Template Deployment](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/resource_group_template_deployment)
- [AzureRM 5.6.0 NetApp Pool](https://registry.terraform.io/providers/hashicorp/azurerm/5.6.0/docs/resources/netapp_pool)
- [Terraform スタイルガイド](https://developer.hashicorp.com/terraform/language/style)

## バージョン更新

`master` をそのまま運用へ追従させず、リリース単位で更新します。

1. 公式リリース、tag の commit、`project.ini` の必要 blob と対象 OS を照合する。
2. `prepare-openpbs.sh` の version/commit、チェックサム一覧、テンプレート登録名を同時に更新する。
3. `--download-only`、スクリプト回帰テスト、Terraform 検証を行う。
4. 新しいテストクラスタで PBS 起動、単体/MPI ジョブ、自動スケール、縮退を確認する。
5. 起動済みクラスタへ変更を強制投入せず、バックアップと移行方法を決める。

Provider を更新する場合は、特に Private DNS Link、Storage、ANF のスキーマ変更を確認してください。lock ファイルも更新し、mock テストだけでなく実環境の plan をレビューします。