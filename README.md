# RFID Pulseira Comanda — MVP

Sistema de comanda por pulseira RFID para parque. App único em Flutter com duas
telas principais: **Garçom** (lançar pedidos) e **Totem** (consulta do cliente),
backend em Firebase (Firestore + Auth).

## Fluxo

1. Garçom abre o app, autentica (Firebase Auth).
2. Garçom aproxima o leitor RFID Bluetooth da pulseira → app lê o UID.
3. App busca/cria a `Comanda` daquele UID no Firestore (`GET` = stream em tempo real).
4. Garçom lança o pedido (ex: "+1 Água") → grava na subcoleção `pedidos`.
5. Cliente vai ao totem, bipa a mesma pulseira, o app mostra os pedidos e o total.

## Modelo de dados (Firestore)

```
comandas/{uid_pulseira}
  ├─ status: "aberta" | "fechada"
  ├─ mesa: "05"                  (opcional, se houver mesas fixas)
  ├─ criadaEm: Timestamp
  ├─ totalCentavos: number       (campo desnormalizado, atualizado a cada pedido)
  └─ pedidos/{pedidoId}
        ├─ produtoId: string
        ├─ nomeProduto: string   (desnormalizado p/ não precisar de join na leitura)
        ├quantidade: number
        ├─ precoUnitCentavos: number
        ├─ garcomId: string
        ├─ garcomNome: string
        └─ criadoEm: Timestamp

produtos/{produtoId}
  ├─ nome: string
  ├─ precoCentavos: number
  └─ ativo: boolean

garcons/{uid_auth}
  ├─ nome: string
  └─ ativo: boolean
```

Por que `uid_pulseira` como ID do documento (e não um ID autogerado)? Porque o
app do garçom faz basicamente um `doc('comandas/$uid').get()` — leitura O(1)
direto pelo UID lido no RFID, sem query. Isso é o "GET /comanda/UID_DA_PULSEIRA"
que você descreveu, só que como leitura direta de documento no Firestore em
vez de uma rota REST.

Valores em **centavos (int)** para evitar erro de ponto flutuante em dinheiro.

## Leitor de pulseira: NFC do celular (como você está testando agora)

O app conversa com uma interface `IRfidReader` (`lib/services/rfid_reader_service.dart`),
então a forma de ler o UID é plugável. Hoje tem 3 implementações:

- **`PhoneNfcReader`** (`lib/services/phone_nfc_reader.dart`) — usa o chip NFC
  do próprio celular via pacote `nfc_manager`. É essa que o `main.dart` já usa
  por padrão em Android/iOS. Serve pra ler **qualquer coisa NFC 13.56MHz**,
  inclusive um **cartão de crédito/débito contactless** — ele só lê o UID/número
  de série do chip, nenhum dado do cartão em si, então dá pra usar como pulseira
  de teste sem risco nenhum.
- **`MockRfidReader`** — digita o UID na mão, usada automaticamente em web/desktop
  (sem NFC) ou se você quiser simular sem nem encostar em nada.
- **Leitor Bluetooth dedicado** (a construir) — quando/se vocês decidirem por um
  leitor externo (Chainway, UHF etc.), criar `ChainwayReader implements IRfidReader`
  e trocar a instância no `main.dart`. O resto do app não muda uma linha.

**Setup pra testar com NFC do celular agora:**

1. Adicionar no `pubspec.yaml`: `nfc_manager: ^3.5.0` (confira a versão mais
   recente em [pub.dev/packages/nfc_manager](https://pub.dev/packages/nfc_manager)
   — a API muda entre major versions; se `phone_nfc_reader.dart` não compilar,
   olhe o exemplo oficial da versão que você instalou).
2. **Android** — em `android/app/src/main/AndroidManifest.xml`, dentro de `<manifest>`:
   ```xml
   <uses-permission android:name="android.permission.NFC" />
   <uses-feature android:name="android.hardware.nfc" android:required="false" />
   ```
3. **iOS** — em `ios/Runner/Info.plist`:
   ```xml
   <key>NFCReaderUsageDescription</key>
   <string>Usado para ler o UID da pulseira/cartão e abrir a comanda</string>
   ```
   E no Xcode: Runner target → Signing & Capabilities → "+ Capability" →
   **Near Field Communication Tag Reading** (gera `Runner.entitlements`).
4. `flutter pub get` e testar em **aparelho físico** (emulador não tem NFC).
5. Abrir o app, ir na tela do Garçom, encostar o cartão de crédito na parte
   de trás do celular (perto da câmera, geralmente) por 1-2 segundos.

**Vale considerar pra produção:** se as pulseiras finais forem NFC padrão
(NTAG213/215, Mifare Ultralight — as mais baratas e comuns), o `PhoneNfcReader`
pode virar a solução definitiva, sem comprar leitor nenhum! Só compensa um
leitor Bluetooth dedicado se vocês precisarem ler de mais longe que alguns cm,
usarem tags UHF (frequência diferente, o NFC do celular não lê), ou quiserem
um terminal fixo em vez do celular do garçom.

## Setup

1. `flutter create` já feito por você — só copiar os arquivos de `lib/` para
   o seu projeto e mesclar o `pubspec.yaml`.
2. Criar projeto no [Firebase Console](https://console.firebase.google.com),
   ativar **Firestore** e **Authentication (Email/senha)**.
3. Rodar `flutterfire configure` no seu projeto para gerar `firebase_options.dart`.
4. Copiar `firestore.rules` para o console do Firebase (aba Firestore → Regras).
5. Popular manualmente alguns documentos em `produtos/` para testar (ex:
   "Água", 500 centavos).
6. Rodar o app: tela de Login → tela do Garçom → encostar o cartão de crédito
   (ou pulseira, quando tiver) na parte de trás do celular → tela da Comanda.

## Dependências a adicionar no `pubspec.yaml`

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: ^3.6.0
  firebase_auth: ^5.3.1
  cloud_firestore: ^5.4.4
  provider: ^6.1.2
  intl: ^0.19.0
  nfc_manager: ^3.5.0   # leitura via NFC do celular (ver seção acima)
  # quando/se plugar um leitor Bluetooth dedicado, adicionar aqui o plugin
  # do fabricante ou flutter_blue_plus: ^1.32.12 se for BLE genérico
```

## Próximos passos depois do MVP

- Fechar comanda (pagamento) e travar novos lançamentos.
- Tela de gestão de produtos (CRUD) para o admin.
- Vincular pulseira física ↔ cliente (nome/CPF) no check-in da entrada.
- Relatório de vendas por garçom/produto (Cloud Function agregando).
- Regras de segurança mais finas (garçom só lança em comanda "aberta").
