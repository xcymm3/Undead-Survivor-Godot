import { mkdir, writeFile } from 'node:fs/promises';
for (const directory of ['node_modules', 'build', 'artifacts']) {
  await mkdir(directory, { recursive: true });
  await writeFile(`${directory}/.gdignore`, '');
}
