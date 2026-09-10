# Web Preview Pipeline

Flow Factory can be tested in a browser without installing Godot locally.

## Target

- Engine: **Godot 4.7.2 stable**
- Export preset: `Web Preview`
- Renderer on Web: Compatibility / WebGL 2
- Browser threads: disabled
- Host: GitHub Pages
- Layout: fixed 9:16 portrait stage

Godot 4 Web exports use the Compatibility renderer/WebGL 2. Browser threading is disabled for this preview so GitHub Pages does not need custom cross-origin isolation headers.

## Automatic flow

A push to `gameplay/sorter-economy-vertical-slice` triggers `.github/workflows/web-preview.yml`.

The workflow performs these gates in order:

1. checkout exact commit;
2. run `scripts/verify_project.py`;
3. restore/download pinned Godot 4.7.2 tooling;
4. verify official download SHA-256 checksums;
5. run `scripts/run_godot_check.sh` headlessly;
6. export `build/web/index.html`;
7. assert that HTML, JavaScript, WebAssembly and PCK outputs exist and are non-empty;
8. write `build-info.json` with commit metadata;
9. upload a 7-day downloadable artifact;
10. upload and deploy the GitHub Pages artifact.

A failed validation or Godot test blocks deployment.

## One-time repository setup

GitHub Pages must use GitHub Actions as its publishing source:

`Settings → Pages → Build and deployment → Source → GitHub Actions`

The GitHub connector used by ChatGPT does not have repository administration permission, so this one setting may need to be enabled manually once.

## Preview URL

For a normal project Pages site the URL is expected to be:

`https://mocchaust64.github.io/rail_game/`

Use the deployment URL shown by the `Deploy Web Preview` job as the source of truth if a custom domain or different Pages configuration is added later.

## Why threading is off

Threaded Godot Web exports require cross-origin isolation (`Cross-Origin-Opener-Policy` and `Cross-Origin-Embedder-Policy`) or a service-worker workaround. For a lightweight QA preview, single-threaded Web export is intentionally preferred because it is simpler, more portable and works on normal GitHub Pages hosting.

This setting affects only the Web preview preset. Android remains on the mobile renderer.

## Browser guidance

Use a recent Chromium-based browser or Firefox for the most reliable WebGL 2 behavior. Safari is supported, but WebGL 2 behavior should be tested separately before treating it as a release target.

## Failure modes

### Build job fails before export

Open the Actions run and inspect the failing test. Deployment is intentionally blocked until the project passes.

### Deploy job says Pages is not configured

Enable GitHub Actions under `Settings → Pages`, then push another commit to the preview branch.

### Browser shows WebGL 2 error

Update the browser or test in Chrome/Edge/Firefox on a device with WebGL 2 support.

### Browser opens but layout looks wrong

Treat that as a product bug. The custom shell constrains the stage to 9:16, so gameplay/UI layout should be evaluated against the same portrait presentation on every desktop tester.
