// Icons: Tabler v3.46.0 (MIT), vendored alongside this script.
const icon = name => {
  const image = document.createElement('img');
  image.src = `/assets/tabler/${name}.svg`;
  image.alt = '';
  image.width = image.height = 20;
  image.setAttribute('aria-hidden', 'true');
  return image;
};
const status = document.createElement('p');
status.className = 'sr-only';
status.setAttribute('role', 'status');
status.setAttribute('aria-live', 'polite');
document.body.append(status);
function copyButton(text, label) {
  const button = document.createElement('button');
  button.type = 'button';
  button.className = 'copy-button';
  button.setAttribute('aria-label', label);
  button.title = label;
  button.append(icon('copy'));
  let reset;
  button.addEventListener('click', async () => {
    clearTimeout(reset);
    status.textContent = '';
    try {
      await navigator.clipboard.writeText(text);
      button.replaceChildren(icon('check'));
      button.title = 'Copied!';
      status.textContent = 'Copied to clipboard.';
    } catch {
      button.replaceChildren(icon('copy'));
      button.title = 'Copy unavailable — select the text to copy manually';
      status.textContent = 'Clipboard access unavailable. Select the text and copy manually.';
    }
    reset = setTimeout(() => {
      button.replaceChildren(icon('copy'));
      button.title = label;
    }, 2200);
  });
  return button;
}
for (const code of document.querySelectorAll('pre, code.command')) {
  const wrapper = document.createElement('div');
  wrapper.className = 'code-block' + (code.classList.contains('command') ? ' command-block' : '');
  code.before(wrapper);
  wrapper.append(code, copyButton(code.textContent, 'Copy code'));
}
for (const item of document.querySelectorAll('[data-package]')) {
  const link = item.querySelector('h2 a');
  const command = `kennel add ${link.textContent}`;
  const row = document.createElement('div');
  row.className = 'package-install';
  const code = document.createElement('code');
  code.textContent = command;
  row.append(code, copyButton(command, `Copy install command for ${link.textContent}`));
  item.append(row);
}
const toggle = document.querySelector('.mobile-menu');
const nav = document.querySelector('#main-nav');
if (toggle && nav) {
  document.documentElement.classList.add('has-menu');
  toggle.hidden = false;
  const setOpen = open => {
    toggle.setAttribute('aria-expanded', String(open));
    toggle.setAttribute('aria-label', open ? 'Close menu' : 'Open menu');
    toggle.replaceChildren(icon(open ? 'x' : 'menu-2'));
    nav.classList.toggle('is-open', open);
  };
  setOpen(false);
  toggle.addEventListener('click', () => setOpen(toggle.getAttribute('aria-expanded') !== 'true'));
  document.addEventListener('keydown', event => {
    if (event.key === 'Escape' && toggle.getAttribute('aria-expanded') === 'true') {
      setOpen(false);
      toggle.focus();
    }
  });
  nav.addEventListener('click', event => {
    if (event.target.closest('a')) setOpen(false);
  });
  matchMedia('(max-width: 700px)').addEventListener('change', () => setOpen(false));
}
