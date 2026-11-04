import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import '../../app/app_controller.dart';
import '../../core/theme/css_gradient.dart';
import '../../core/theme/palette.dart';
import '../../models/design_model.dart';
import '../../state/catalog_cubit.dart';
import '../../state/settings_cubit.dart';
import '../../state/studio_cubit.dart';
import '../widgets/coin.dart';
import '../widgets/common.dart';
import '../widgets/design_canvas.dart';
import '../widgets/kit.dart';
import '../widgets/synced_fields.dart';

/// `studio`: the creator's dashboard, design list and upload form.
class StudioScreen extends StatelessWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<SettingsCubit>().state.t;
    final st = context.watch<StudioCubit>().state;
    final mine = context.watch<CatalogCubit>().state.mine;
    final studio = context.read<StudioCubit>();

    Widget body;
    switch (st.tab) {
      case 'Dashboard':
        body = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ArtifactGrid(columns: 3, children: [
            _Stat('${mine.length}', 'Designs'),
            const _Stat('1,284', 'Uses'),
            const _Stat('₹12,480', 'Earnings'),
          ]),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 4.2, 16, 4.2),
            child: _Muted('Sample figures for the prototype.', 11),
          ),
          const SectionTitle('Your designs'),
          if (mine.isEmpty)
            EmptyState(
                title: 'No designs yet',
                message: 'Upload your first design.',
                buttonLabel: 'Upload Design',
                onButton: () => studio.setTab('Upload'))
          else
            for (final d in mine) _StudioRow(d),
        ]);
      case 'My Designs':
        body = mine.isEmpty
            ? EmptyState(
                title: 'No designs yet',
                message: 'Your uploaded designs will appear here.',
                buttonLabel: 'Upload Design',
                onButton: () => studio.setTab('Upload'))
            : Column(children: [
                for (final d in mine) _StudioRow(d, actions: true),
              ]);
      default:
        body = const _UploadForm();
    }

    return Column(children: [
      TitleHeader(t('studio')),
      Segmented(
        options: const ['Dashboard', 'My Designs', 'Upload'],
        selected: st.tab,
        onChanged: studio.setTab,
      ),
      Expanded(
        child: ListView(
            padding: EdgeInsets.zero,
            children: [body, const SizedBox(height: 16)]),
      ),
      const BottomTabs(),
    ]);
  }
}

class _Muted extends StatelessWidget {
  const _Muted(this.text, this.size);

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) =>
      CoinText(text, style: TextStyle(fontSize: size, color: context.pal.mu));
}

class _Stat extends StatelessWidget {
  const _Stat(this.value, this.label);

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
          color: pal.c, borderRadius: BorderRadius.circular(14), boxShadow: pal.sh),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: kBold)),
        Text(label, style: TextStyle(fontSize: 12, color: pal.mu)),
      ]),
    );
  }
}

/// `li(d, act)`: a creator design row.
class _StudioRow extends StatelessWidget {
  const _StudioRow(this.design, {this.actions = false});

  final DesignModel design;
  final bool actions;

  @override
  Widget build(BuildContext context) {
    return ListCard(children: [
      SizedBox(
        width: 64,
        child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: DesignCanvas(design: design)),
      ),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(design.name, style: const TextStyle(fontWeight: kSemi)),
          const SizedBox(height: 2),
          Wrap(spacing: 4, runSpacing: 4, children: [
            Tag(design.cat),
            const Tag('🪙 1 coin'),
          ]),
          if (actions)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(children: [
                AppButton('Edit',
                    small: true,
                    style: BtnStyle.ghost,
                    onTap: () => context.app.editTemplate(design)),
                const SizedBox(width: 8),
                AppButton('Delete',
                    small: true,
                    style: BtnStyle.danger,
                    onTap: () => context.app.deleteTemplate(design.id)),
              ]),
            ),
        ]),
      ),
    ]);
  }
}

Future<void> _pickImage(
    BuildContext context, void Function(Uint8List bytes) onPicked) async {
  try {
    final f = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 720,
        maxHeight: 720,
        imageQuality: 80);
    if (f == null) return;
    onPicked(await f.readAsBytes());
  } catch (_) {
    if (context.mounted) context.app.toast('Could not open the gallery');
  }
}

class _UploadForm extends StatelessWidget {
  const _UploadForm();

  @override
  Widget build(BuildContext context) {
    final pal = context.pal;
    final st = context.watch<StudioCubit>().state;
    final studio = context.read<StudioCubit>();
    final u = st.form;
    final cat = context.watch<CatalogCubit>().state;
    final editing = st.editingId != 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FractionallySizedBox(
          widthFactor: .58,
          child: Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14), boxShadow: pal.sh),
            clipBehavior: Clip.antiAlias,
            child: DesignCanvas(design: u.toDesign(st.editingId, cat.backgrounds)),
          ),
        ),
        const SizedBox(height: 4),
        const Center(child: _Muted('Live preview', 11)),
        const FieldLabel('Design name'),
        LiveTextField(
            value: u.name, onChanged: (v) => studio.update((f) => f.copyWith(name: v))),
        const FieldLabel('Category'),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in cat.categories)
            CategoryChip(c,
                on: u.cat == c,
                onTap: () => studio.update((f) => f.copyWith(cat: c))),
        ]),
        const FieldLabel('Description'),
        LiveTextField(
            value: u.desc,
            maxLines: 2,
            minLines: 2,
            onChanged: (v) => studio.update((f) => f.copyWith(desc: v))),
        const FieldLabel('Headline'),
        LiveTextField(
            value: u.headline,
            maxLines: 2,
            minLines: 2,
            onChanged: (v) => studio.update((f) => f.copyWith(headline: v))),
        const FieldLabel('Subtitle'),
        LiveTextField(
            value: u.subtitle,
            onChanged: (v) => studio.update((f) => f.copyWith(subtitle: v))),
        const FieldLabel('Main image'),
        ArtifactGrid(columns: 6, padding: EdgeInsets.zero, children: [
          for (final a in cat.assets.take(6))
            AssetCell(a.emoji,
                fontSize: 22,
                on: u.emoji == a.emoji,
                onTap: () => studio.update(
                    (f) => f.copyWith(emoji: a.emoji, clearMainImage: true))),
        ]),
        const SizedBox(height: 8),
        AppButton(
          u.mainImage != null
              ? '✓ Main image uploaded · change'
              : '⬆ Upload main image from gallery',
          style: BtnStyle.ghost,
          wide: true,
          fontSize: 13,
          onTap: () => _pickImage(context,
              (b) => studio.update((f) => f.copyWith(mainImage: b))),
        ),
        if (u.mainImage != null)
          Tap(
            onTap: () => studio.update((f) => f.copyWith(clearMainImage: true)),
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: _Muted('Remove uploaded image', 12),
            ),
          ),
        const FieldLabel('Background'),
        ArtifactGrid(columns: 6, padding: EdgeInsets.zero, children: [
          for (var i = 0; i < cat.backgrounds.length; i++)
            Tap(
              onTap: () => studio.update(
                  (f) => f.copyWith(gradient: i, clearBgImage: true)),
              child: Container(
                height: 36,
                decoration: BoxDecoration(
                  gradient: CssLinearGradient(145, cat.backgrounds[i]),
                  borderRadius: BorderRadius.circular(14),
                  border: u.gradient == i && u.bgImage == null
                      ? Border.all(color: pal.p, width: 2)
                      : Border.all(color: pal.ln),
                ),
              ),
            ),
        ]),
        const SizedBox(height: 8),
        AppButton(
          u.bgImage != null
              ? '✓ Image uploaded · change'
              : '⬆ Upload background image',
          style: BtnStyle.ghost,
          wide: true,
          fontSize: 13,
          onTap: () => _pickImage(
              context, (b) => studio.update((f) => f.copyWith(bgImage: b))),
        ),
        const SizedBox(height: 12),
        const _Muted(
            '🪙 Customers use 1 coin to customise each design, then can reuse it anytime. Your own designs are always free for you.',
            12),
        const SizedBox(height: 14),
        AppButton(editing ? 'Save changes' : 'Publish design',
            wide: true, onTap: context.app.publishDesign),
        if (editing) ...[
          const SizedBox(height: 8),
          AppButton('Cancel',
              style: BtnStyle.ghost, wide: true, onTap: studio.cancelEdit),
        ],
      ]),
    );
  }
}
