# Build iOS de nuvem sem Mac (→ TestFlight)

Quando não há Mac na equipe, o `.ipa` é buildado, assinado e enviado ao TestFlight por um serviço
de build de nuvem (`org.build.servico`; a receita abaixo é do Codemagic, mas o padrão vale para
qualquer um). A config vive no repo (`codemagic.yaml` na RAIZ); as credenciais, na UI do serviço.

> Os nomes entre `<>` vêm da configuração — ver `references/configuracao.md`. Não invente nenhum:
> o build falha silenciosamente quando o nome não bate com o que está cadastrado na UI.

## Setup único na UI (humano faz 1x — não automatizável via repo)

1. Entrar no serviço com a conta que enxerga a organização do GitHub (`<org.github_org>`).
2. Add application → escolher o repo → "I have a codemagic.yaml".
3. **Team → Integrations → App Store Connect → Add key:** o `.p8` gerado em ASC
   (*Users and Access → Integrations → App Store Connect API*, role Admin/App Manager).
   Preencher **Name = `<org.build.asc_key_name>`** (exato — o yaml referencia por esse nome),
   **Key ID = `<org.asc.key_id>`** e **Issuer ID = `<org.asc.issuer_id>`**.
4. Criar o app em ASC e copiar o **Apple ID numérico** (App Information → General → Apple ID) →
   é o `<app.apple_id_numerico>`.
5. Criar o grupo de variáveis **`<org.build.var_group>`** com o secret
   **`<org.build.secret_cert>`** — a chave RSA estável em base64 de linha única, normalizada p/ LF:
   `openssl genrsa 2048` → base64.

## Por que a chave privada estável

O `ios_signing` automático **busca** mas **não cria** o provisioning profile de um bundle novo, e
baixar o certificado existente do time vem **sem a chave privada**. Solução: reconstituir a **sua**
chave RSA estável (secret em base64) e rodar `fetch-signing-files --certificate-key @file:... --create`
→ o serviço **cria (1ª vez) e reutiliza sempre o MESMO certificado**, sem estourar o limite de 2
certificados iOS Distribution da Apple.

## Pré-requisitos no repo (senão o build quebra)

- 🔴 **`ios/Podfile` commitado** com `platform :ios, '<default.ios_deployment_target>'` +
  `post_install` forçando `IPHONEOS_DEPLOYMENT_TARGET` em todos os pods (o Firebase exige iOS 13+;
  Podfile ausente assume iOS 12 → `pod install` falha).
- Guard try/catch no `Firebase.initializeApp` (sobe sem push em vez de crashar sem
  `GoogleService-Info.plist`).
- iPhone-only: `TARGETED_DEVICE_FAMILY="<default.targeted_device_family>"`.

## Template `codemagic.yaml` (raiz do repo)

Substitua cada `<chave>` pelo valor da configuração:

```yaml
workflows:
  ios-testflight:
    name: <app.nome_exibicao> iOS – TestFlight
    instance_type: <default.build.instance_type>
    max_build_duration: <default.build.max_duration>
    integrations:
      app_store_connect: <org.build.asc_key_name>   # Name exato cadastrado na UI
    environment:
      groups:
        - <org.build.var_group>                     # contém <org.build.secret_cert> (base64)
      vars:
        APP_ID: <app.apple_id_numerico>
        FLUTTER_PROJECT_DIR: "<app.projeto_dir>"    # a subpasta do app, em monorepo
      flutter: <default.build.flutter_channel>
      xcode: <default.build.xcode>
      cocoapods: <default.build.cocoapods>
    scripts:
      - name: Flutter pub get
        script: cd "$FLUTTER_PROJECT_DIR" && flutter pub get
      - name: CocoaPods (Podfile commitado)
        script: cd "$FLUTTER_PROJECT_DIR/ios" && pod install
      - name: Assinatura (cert próprio estável + profile via ASC key)
        script: |
          keychain initialize
          echo "$<org.build.secret_cert>" | base64 --decode > /tmp/ios_cert_key.pem
          app-store-connect fetch-signing-files "<app.id_ios>" \
            --type IOS_APP_STORE --certificate-key @file:/tmp/ios_cert_key.pem --create
          keychain add-certificates
          xcode-project use-profiles
      - name: Build IPA
        script: |
          cd "$FLUTTER_PROJECT_DIR"
          BUILD_NUMBER=$(($(app-store-connect get-latest-testflight-build-number "$APP_ID" 2>/dev/null || echo 0) + 1))
          flutter build ipa --release --build-name=<versão> --build-number=$BUILD_NUMBER \
            --export-options-plist=/Users/builder/export_options.plist
    artifacts:
      - <app.projeto_dir>/build/ios/ipa/*.ipa
      - /tmp/xcodebuild_logs/*.log
    publishing:
      email:
        recipients: [ <org.build.notificacao_email> ]
        notify: { success: true, failure: true }
      app_store_connect:
        auth: integration
        submit_to_testflight: true      # só TestFlight; a revisão da App Store é manual no painel
```

## Notas

- `submit_to_testflight: true` sobe o `.ipa`; fica "Post-processing" ~5-15 min. **Não** é submissão
  de review.
- `ITSAppUsesNonExemptEncryption=false` evita o prompt de export compliance no TestFlight.
- **Monorepo:** no onboarding, Project path = pasta do app; o `codemagic.yaml` precisa estar **na
  branch buildada**.
- `--build-name` usa a versão do app (na primeira, `<default.versao_inicial>` sem o `+build`);
  depois, só o `--build-number` cresce.
