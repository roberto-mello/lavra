// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';
import icon from 'astro-icon';

// https://astro.build/config
export default defineConfig({
  site: 'https://lavra.dev',
  output: 'static',
  vite: {
    plugins: [tailwindcss()],
  },
  integrations: [
    icon({
      include: {
        ph: ['terminal-window', 'brain', 'git-branch', 'lightning', 'rocket', 'copy', 'check', 'github-logo', 'arrow-right', 'list-bullets', 'code', 'users-three', 'command'],
      },
    }),
  ],
});
