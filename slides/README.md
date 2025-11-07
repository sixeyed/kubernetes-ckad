# Slidev

> https://sli.dev

## Install

Node & NPM

Then - global installs:

```
sudo npm i -g pnpm
```

For exporting to PNG:

```
pnpm i -D playwright-chromium

pnpm exec playwright install
```


## Export to PNG

- Copy `package.json` to slides dir

- Install deps

```
pnpm install
```

- Test

```
pnpm exec slidev
```

- Export

```
pnpm exec slidev export --with-clicks slides.md --format png --scale 0.98 --output ./slides
```

> Scale depends on monitor resolution

```
# 3920 * 0.49 ≈ 1920, 2208 * 0.49 ≈ 1082
# 2940 * 0.65 ≈ 1911, 1656 * 0.65 ≈ 1076
# 1960 * 0.98 = 1920, 1104 * 0.98 = 1082
```