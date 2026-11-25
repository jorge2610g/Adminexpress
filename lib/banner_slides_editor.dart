import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class BannerSlideDraft {
  String imageUrl;
  String videoUrl;
  String mediaType;
  String targetUrl;
  Uint8List? bytes;
  String filename;
  BannerSlideDraft(
      {this.imageUrl = '',
      this.videoUrl = '',
      this.mediaType = 'image',
      this.targetUrl = '',
      this.bytes,
      this.filename = ''});
}

/// A campaign owns its ordered images and each image's destination link.
class BannerSlidesEditor extends StatelessWidget {
  final List<BannerSlideDraft> slides;
  final VoidCallback onChanged;
  final ValueChanged<String> onError;
  final bool enabled;
  final String defaultLink;
  final double imageAspectRatio;
  final String imageSizeLabel;
  const BannerSlidesEditor(
      {super.key,
      required this.slides,
      required this.onChanged,
      required this.onError,
      this.enabled = true,
      this.defaultLink = '',
      this.imageAspectRatio = 3.2,
      this.imageSizeLabel = '1280 × 400 px'});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Piezas del carrusel (${slides.length}/20)',
              style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
              'Combina imágenes y videos. Cada pieza tiene su propio enlace.'),
          Text(
            'Medida recomendada para esta posición: $imageSizeLabel. '
            'Si la imagen tiene otra medida, se amplía y recorta para llenar el marco.',
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < slides.length; i++)
            Card(
                key: ObjectKey(slides[i]),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Row(children: [
                      Expanded(
                          child: Text(
                              '${slides[i].mediaType == 'video' ? 'Video' : 'Imagen'} ${i + 1}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700))),
                      IconButton(
                          tooltip: 'Subir imagen de posición',
                          onPressed: !enabled || i == 0
                              ? null
                              : () {
                                  final slide = slides.removeAt(i);
                                  slides.insert(i - 1, slide);
                                  onChanged();
                                },
                          icon: const Icon(Icons.arrow_upward_rounded)),
                      IconButton(
                          tooltip: 'Bajar imagen de posición',
                          onPressed: !enabled || i == slides.length - 1
                              ? null
                              : () {
                                  final slide = slides.removeAt(i);
                                  slides.insert(i + 1, slide);
                                  onChanged();
                                },
                          icon: const Icon(Icons.arrow_downward_rounded)),
                      IconButton(
                          tooltip: 'Quitar imagen ${i + 1}',
                          onPressed: !enabled
                              ? null
                              : () {
                                  slides.removeAt(i);
                                  onChanged();
                                },
                          icon: const Icon(Icons.delete_outline_rounded)),
                    ]),
                    AspectRatio(
                      aspectRatio: imageAspectRatio,
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: ColoredBox(
                          color: Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                          child: slides[i].mediaType == 'video'
                              ? const Center(
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.play_circle_outline, size: 42),
                                      Text('Video · se reproducirá en bucle'),
                                    ],
                                  ),
                                )
                              : slides[i].bytes != null
                                  ? Image.memory(slides[i].bytes!,
                                      fit: BoxFit.cover)
                                  : Image.network(slides[i].imageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) =>
                                          const Icon(Icons.image_outlined)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                        initialValue: slides[i].targetUrl,
                        enabled: enabled,
                        decoration: InputDecoration(
                            labelText: 'URL de enlace ${i + 1} *',
                            hintText: 'https://...'),
                        onChanged: (value) => slides[i].targetUrl = value),
                  ]),
                )),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            icon: const Icon(Icons.add_photo_alternate_outlined),
            label: const Text('Añadir imágenes al carrusel'),
            onPressed: !enabled || slides.length >= 20
                ? null
                : () async {
                    try {
                      final files = await ImagePicker()
                          .pickMultiImage(maxWidth: 1600, imageQuality: 86);
                      if (!context.mounted) return;
                      if (files.length + slides.length > 20) {
                        onError('Puedes cargar hasta 20 imágenes por banner.');
                        return;
                      }
                      final picked = <BannerSlideDraft>[];
                      for (final file in files) {
                        final bytes = await file.readAsBytes();
                        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
                          if (context.mounted)
                            onError(
                                '${file.name}: la imagen debe pesar menos de 5 MB.');
                          return;
                        }
                        picked.add(BannerSlideDraft(
                            bytes: bytes,
                            filename: file.name,
                            targetUrl: defaultLink));
                      }
                      if (!context.mounted) return;
                      slides.addAll(picked);
                      onChanged();
                    } catch (_) {
                      if (context.mounted)
                        onError(
                            'No pudimos cargar las imágenes. Inténtalo nuevamente.');
                    }
                  },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.video_library_outlined),
            label: const Text('Añadir video al carrusel'),
            onPressed: !enabled || slides.length >= 20
                ? null
                : () async {
                    try {
                      final file = await ImagePicker().pickVideo(
                        source: ImageSource.gallery,
                      );
                      if (!context.mounted || file == null) return;
                      final bytes = await file.readAsBytes();
                      if (bytes.lengthInBytes > 20 * 1024 * 1024) {
                        onError('El video debe pesar menos de 20 MB.');
                        return;
                      }
                      slides.add(BannerSlideDraft(
                        mediaType: 'video',
                        bytes: bytes,
                        filename: file.name,
                        targetUrl: defaultLink,
                      ));
                      onChanged();
                    } catch (_) {
                      if (context.mounted) {
                        onError(
                            'No pudimos cargar el video. Inténtalo otra vez.');
                      }
                    }
                  },
          ),
        ],
      );
}
