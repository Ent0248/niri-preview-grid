#!/bin/bash


VERSION=$(grep '^version' Cargo.toml | head -1 | cut -d '"' -f2)
if [[ "$VERSION" != "25.11.0" ]]; then
    echo -en "\033[1;33m该补丁是25.11.0版本编写的,当前版本:\033[1;31m$VERSION\033[1;33m 是否继续?(y/n)\033[0m"
    read input
    if [[ "$input" != "y" ]]; then
        exit
    fi
fi


# 固定预览时的水平滑动
sed -i '/fn compute_view_pos(&self) -> f64 {/,/^    }/c\
    fn compute_view_pos(&self) -> f64 {\
        0.0\
    }' src/ui/mru.rs


sed -i '/fn thumbnails(&self) -> impl Iterator/,/^    }/c\
    fn thumbnails(&self) -> impl Iterator<Item = (&Thumbnail, Rectangle<f64, Logical>)> {\
        let thumbnails: Vec<_> = self.wmru.thumbnails().collect();\
        let count = thumbnails.len();\
        if count == 0 {\
            return vec![].into_iter();\
        }\
\
        let output_size = output_size(&self.output);\
        let scale = self.output.current_scale().fractional_scale();\
        let round = move |logical: f64| round_logical_in_physical(scale, logical);\
\
        let config = self.config.borrow();\
        let _padding = round(config.recent_windows.highlight.padding as f64) + round(BORDER);\
        let gap = round(GAP);\
\
        let margin = round(40.0);\
        let max_width = output_size.w - margin * 2.0;\
        let max_height = output_size.h - margin * 2.0;\
\
        let original_sizes: Vec<Size<f64, Logical>> = thumbnails\
            .iter()\
            .map(|t| t.preview_size(output_size, scale))\
            .collect();\
\
        let mut best_layout: Option<(usize, usize, f64, f64, f64, f64)> = None;\
        let mut best_aspect_diff = f64::MAX;\
\
        for cols in 1..=count.min(6) {\
            let rows = (count + cols - 1) / cols;\
            let cell_width_by_width = (max_width - (cols - 1) as f64 * gap) / cols as f64;\
            let cell_height_by_height = (max_height - (rows - 1) as f64 * gap) / rows as f64;\
            let cell_size = cell_width_by_width.min(cell_height_by_height);\
            let cell_width = cell_size;\
            let cell_height = cell_size;\
            let total_width = cols as f64 * cell_width + (cols - 1) as f64 * gap;\
            let total_height = rows as f64 * cell_height + (rows - 1) as f64 * gap;\
\
            if total_width > max_width + 1e-6 || total_height > max_height + 1e-6 {\
                continue;\
            }\
\
            let aspect = total_width / total_height;\
            let screen_aspect = max_width / max_height;\
            let diff = (aspect - screen_aspect).abs();\
\
            if diff < best_aspect_diff {\
                best_aspect_diff = diff;\
                best_layout = Some((cols, rows, cell_width, cell_height, total_width, total_height));\
            }\
        }\
\
        let (cols, rows, cell_width, cell_height, total_width, total_height) = best_layout.unwrap_or_else(|| {\
            let cols = count.min(6);\
            let rows = (count + cols - 1) / cols;\
            let cell_width = (max_width - (cols - 1) as f64 * gap) / cols as f64;\
            let cell_height = (max_height - (rows - 1) as f64 * gap) / rows as f64;\
            let total_width = cols as f64 * cell_width + (cols - 1) as f64 * gap;\
            let total_height = rows as f64 * cell_height + (rows - 1) as f64 * gap;\
            (cols, rows, cell_width, cell_height, total_width, total_height)\
        });\
\
        let mut preview_sizes = Vec::with_capacity(count);\
        for i in 0..count {\
            let orig = original_sizes[i];\
            let scale = (cell_width / orig.w).min(cell_height / orig.h);\
            let width = orig.w * scale;\
            let height = orig.h * scale;\
            preview_sizes.push(Size::from((width, height)));\
        }\
\
        let start_x = (output_size.w - total_width) / 2.0;\
        let start_y = (output_size.h - total_height) / 2.0;\
\
        let result: Vec<_> = (0..count)\
            .map(|i| {\
                let row = i / cols;\
                let col = i % cols;\
                let size = preview_sizes[i];\
                let cell_x = start_x + col as f64 * (cell_width + gap);\
                let cell_y = start_y + row as f64 * (cell_height + gap);\
                let x_offset = (cell_width - size.w) / 2.0;\
                let y_offset = (cell_height - size.h) / 2.0;\
                let final_x = cell_x + x_offset;\
                let final_y = cell_y + y_offset;\
                let loc = Point::new(round(final_x), round(final_y));\
                (thumbnails[i], Rectangle::new(loc, size))\
            })\
            .collect();\
\
        result.into_iter()\
    }' src/ui/mru.rs
