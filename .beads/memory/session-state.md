# Session State
## Current Position
- Bead: bdcompound-ek0 -- Integrate docs into lavra site
- Phase: Build fix needed
## Just Completed
- Moved docs/ to site/src/content/docs/, symlink back
- Added frontmatter to all docs
- Created Doc layout, dynamic route, docs index, wired Nav
- Build fails: Astro 5 requires glob loader syntax in src/content.config.ts
## Next
- Fix src/content.config.ts with Astro 5 glob loader syntax
- Run bun run build to verify
- Commit and push
## Key Fix Needed
Astro 5 content.config.ts syntax:
```ts
import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';
const docs = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/docs' }),
  schema: z.object({ title: z.string(), description: z.string(), order: z.number().optional() }),
});
export const collections = { docs };
```
Slug from glob loader is the file path without extension (e.g. "CATALOG", "releases/v0.7.0").
URL mapping: lowercase + underscores-to-hyphens.
