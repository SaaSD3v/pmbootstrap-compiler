# postmarketOS Builder

Compilador de imagens postmarketOS com GitHub Actions.

A branch `main` contém somente os workflows e scripts do compilador. As configurações de cada aparelho ficam nas branches `device/*`.

## Dispositivos

- `device/motorola-channel` — Motorola Moto G7 Play
- `device/motorola-ocean` — Motorola Moto G7 Power
- `device/samsung-a21s` — Samsung Galaxy A21s

## Actions

Existem três opções:

- **postmarketOS Console**
- **postmarketOS Phosh**
- **postmarketOS Headless Console**

Ao iniciar manualmente uma build, escolha a branch do aparelho. Também é possível alterar a senha, chave SSH e as refs de pmaports/pmbootstrap.

A senha padrão usada pelo projeto é `123456`. Ela pode ser alterada pelo campo `pmos_password` no Actions.

## Saída

As builds geram os arquivos exportados pelo pmbootstrap, um Artifact no GitHub e envio dos arquivos para o Gofile.

Cada branch de dispositivo possui seu próprio README com os pacotes e fontes usados.
