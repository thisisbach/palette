import base64
from pathlib import Path
import runpy
import tempfile
import unittest
import xml.etree.ElementTree as ET

release = runpy.run_path(str(Path(__file__).resolve().parents[1] / 'Scripts/publish-release.py'))


class UpdateFeedTests(unittest.TestCase):
    def test_versions_and_rejected_tags(self):
        parse = release['version_tuple']
        self.assertEqual(parse('v1.2'), parse('1.2.0'))
        self.assertGreater(parse('v1.10.0'), parse('v1.9.9'))
        for invalid in ['v1.2-beta', '../v1.2', 'v01.2', 'v1', 'v1.2;echo bad', '1.2.3.4']:
            with self.assertRaises(ValueError):
                parse(invalid)

    def test_feed_matches_the_packaged_app(self):
        with tempfile.TemporaryDirectory() as temporary:
            archive = Path(temporary) / 'Palette-1.2-macOS-universal.zip'
            archive.write_bytes(b'archive bytes')
            info = {'CFBundleShortVersionString': '1.2', 'CFBundleVersion': '1.2', 'LSMinimumSystemVersion': '14.0'}
            signature = base64.b64encode(bytes(64)).decode()
            feed = ET.fromstring(release['make_feed']('v1.2', info, archive, signature))
            ns = {'sparkle': release['SPARKLE']}
            self.assertEqual(feed.findtext('channel/item/sparkle:version', namespaces=ns), '1.2')
            self.assertEqual(feed.findtext('channel/item/sparkle:minimumSystemVersion', namespaces=ns), '14.0')
            item = feed.find('channel/item/enclosure')
            self.assertEqual(item.attrib['length'], str(archive.stat().st_size))
            self.assertEqual(item.attrib['url'], 'https://github.com/thisisbach/palette/releases/download/v1.2/Palette-1.2-macOS-universal.zip')
            self.assertEqual(item.attrib['{' + release['SPARKLE'] + '}edSignature'], signature)


if __name__ == '__main__':
    unittest.main()
