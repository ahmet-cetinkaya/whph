import puppeteer from 'puppeteer';
import fs from 'fs-extra';
import path from 'path';

const METADATA_DIR = path.resolve(__dirname, '../../fastlane/metadata/android');
const TEMPLATE_PATH = path.resolve(__dirname, 'template.html');

const TRANSLATIONS_PATH = path.resolve(__dirname, 'translations.json');

async function main() {
    console.log('Starting feature graphic generation...');

    if (!fs.existsSync(METADATA_DIR)) {
        console.error(`Metadata directory not found at ${METADATA_DIR}`);
        process.exit(1);
    }

    // Load translations
    let allTranslations: Record<string, Record<string, string>> = {};
    if (fs.existsSync(TRANSLATIONS_PATH)) {
        allTranslations = await fs.readJson(TRANSLATIONS_PATH);
    } else {
        console.warn('Translations file not found, using defaults.');
    }


    // Launch browser
    const browser = await puppeteer.launch({
        args: ['--no-sandbox', '--disable-setuid-sandbox'],
        headless: true
    });

    try {
        const page = await browser.newPage();
        await page.setViewport({ width: 1024, height: 500 }); // Feature graphic size

        const locales = await fs.readdir(METADATA_DIR);

        for (const locale of locales) {
            const localePath = path.join(METADATA_DIR, locale);
            if (!(await fs.stat(localePath)).isDirectory()) continue;

            console.log(`Processing locale: ${locale}`);

            // Read standard metadata
            const titlePath = path.join(localePath, 'title.txt');
            const subtitlePath = path.join(localePath, 'short_description.txt');
            const iconPath = path.join(localePath, 'images', 'icon.png');

            let title = '';
            let subtitle = '';
            let localeIconBase64 = '';

            // Get translations for this locale, fallback to default, then empty object
            const featureTexts = allTranslations[locale] || allTranslations['default'] || {};

            if (fs.existsSync(titlePath)) {
                title = (await fs.readFile(titlePath, 'utf8')).trim();
            }
            if (fs.existsSync(subtitlePath)) {
                subtitle = (await fs.readFile(subtitlePath, 'utf8')).trim();
            }
            if (fs.existsSync(iconPath)) {
                const iconBuffer = await fs.readFile(iconPath);
                localeIconBase64 = `data:image/png;base64,${iconBuffer.toString('base64')}`;
            }

            // Load template
            // We pass title/subtitle in URL for simplicity in basic cases, but we can also inject via evaluate
            const url = `file://${TEMPLATE_PATH}`;
            await page.goto(url, { waitUntil: 'networkidle0' });

            // Inject Data
            await page.evaluate((data) => {
                // Inject Icon
                if (data.localeIconBase64) {
                    const iconImg = document.getElementById('app-icon-img') as HTMLImageElement;
                    if (iconImg) {
                        iconImg.src = data.localeIconBase64;
                    }
                }

                // Inject Texts
                if (data.title) {
                    const el = document.getElementById('title');
                    if (el) el.textContent = data.title;
                }
                if (data.subtitle) {
                    const el = document.getElementById('subtitle');
                    if (el) el.textContent = data.subtitle;
                }

                // Inject Feature Texts if present
                if (data.featureTexts) {
                    const features = ['feature-1', 'feature-2', 'feature-3'];
                    features.forEach(feature => {
                        const line1 = data.featureTexts[`${feature}-line1`];
                        const line2 = data.featureTexts[`${feature}-line2`];

                        if (line1) {
                            const el = document.getElementById(`${feature}-line1`);
                            if (el) el.textContent = line1;
                        }
                        if (line2) {
                            const el = document.getElementById(`${feature}-line2`);
                            if (el) el.textContent = line2;
                        }
                    });
                }

            }, {
                localeIconBase64,
                title,
                subtitle,
                featureTexts
            });

            // Ensure output directory exists
            const outputDir = path.join(localePath, 'images');
            await fs.ensureDir(outputDir);

            const outputPath = path.join(outputDir, 'featureGraphic.png');
            await page.screenshot({ path: outputPath });
            console.log(`Saved: ${outputPath}`);
        }

    } catch (error) {
        console.error('Error generating feature graphics:', error);
    } finally {
        await browser.close();
    }
}

main().catch(console.error).finally(() => process.exit(0));
