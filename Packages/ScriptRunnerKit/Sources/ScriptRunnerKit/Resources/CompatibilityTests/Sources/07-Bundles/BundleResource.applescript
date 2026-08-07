use scripting additions

-- Compile this source as BundleResource.scptd and place payload.txt in Contents/Resources.
set resourceAlias to path to resource "payload.txt"
set resourceText to read resourceAlias as «class utf8»
return {resourceContents:resourceText, scriptLocation:((path to me) as text)}
